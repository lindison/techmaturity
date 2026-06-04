require "net/http"
require "uri"
require "json"

# Uses an LLM (via OpenRouter) to score a repository's capabilities against the
# framework's actual 1-4 rubrics — the deep analysis the file-presence detectors
# can't do (e.g. Code Commenting Strategy, Code Reuse). Returns the same Finding
# struct as RepoAssessmentService so the two can be merged.
class AiRepoAnalyzer
  ENDPOINT  = "https://openrouter.ai/api/v1/chat/completions"
  MODEL     = ENV.fetch("AI_ANALYSIS_MODEL", "qwen/qwen3-coder-next")
  MAX_CHARS = 60_000          # total repo context sent to the model
  MAX_FILE  = 4_000           # per-file cap
  MAX_FILES = 60

  SKIP_DIRS = %w[.git node_modules vendor tmp log dist build .bundle coverage .yarn target].freeze
  CODE_EXT  = %w[.rb .py .js .ts .jsx .tsx .go .java .rs .php .cs .kt .swift .scala .c .cc .cpp .h .hpp
                 .sh .sql .md .yml .yaml .tf .gradle .erb].freeze

  def self.available?
    CONFIGS[:enable_ai_analysis] && ENV["OR_DELPHI_API_KEY"].present?
  end

  def initialize(dir, framework)
    @dir = dir
    @framework = framework
  end

  # Returns an array of RepoAssessmentService::Finding (possibly empty).
  def analyze
    return [] unless self.class.available? && @framework

    context = gather_context
    return [] if context.blank?

    rows = parse_levels(chat(messages_for(context)))
    findings_from(rows)
  rescue => e
    Rails.logger.warn("AI repo analysis failed: #{e.class}: #{e.message}")
    []
  end

  # Exposed for testing: maps parsed rows to validated findings.
  def findings_from(rows)
    by_slug = @framework.capabilities.index_by(&:slug)
    Array(rows).filter_map do |row|
      slug  = row["slug"]
      level = row["level"]
      capability = by_slug[slug]
      next unless capability && level.is_a?(Integer) && (1..4).cover?(level)

      RepoAssessmentService::Finding.new(key: slug, title: capability.name, level: level,
                                         note: "AI: #{row['evidence']}".strip)
    end
  end

  # Exposed for testing: pulls the JSON array out of the model's reply.
  def parse_levels(content)
    json = content.to_s[/\[.*\]/m]
    json ? JSON.parse(json) : []
  rescue JSON::ParserError
    []
  end

  private

  def messages_for(context)
    rubric = @framework.capabilities.map do |capability|
      levels = (1..4).map { |v| "    #{v}. #{capability.level(v)&.description}" }.join("\n")
      "- #{capability.slug} — #{capability.name}:\n#{levels}"
    end.join("\n")

    system = "You are a staff engineer assessing a code repository against a maturity model. " \
             "For each capability, choose the single maturity level (1-4) best supported by the " \
             "repository's contents, or null if it genuinely cannot be judged from code/config. " \
             "Judge strictly from evidence in the provided files; do not assume."

    user = "MATURITY CAPABILITIES (slug, name, and the four levels):\n#{rubric}\n\n" \
           "REPOSITORY FILES:\n#{context}\n\n" \
           "Respond with ONLY a JSON array, one object per capability you can judge:\n" \
           "[{\"slug\":\"<slug>\",\"level\":<1-4 or null>,\"evidence\":\"<one short sentence>\"}]"

    [{ role: "system", content: system }, { role: "user", content: user }]
  end

  def chat(messages)
    uri = URI(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 120

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{ENV['OR_DELPHI_API_KEY']}"
    request["Content-Type"] = "application/json"
    request["HTTP-Referer"] = "https://github.com/lindison/techmaturity"
    request["X-Title"] = "Tech Maturity"
    request.body = { model: MODEL, messages: messages, temperature: 0 }.to_json

    response = http.request(request)
    raise "OpenRouter #{response.code}: #{response.body.to_s[0, 200]}" unless response.code.to_i == 200

    JSON.parse(response.body).dig("choices", 0, "message", "content")
  end

  def gather_context
    buffer = +""
    collect_files.each do |path|
      relative = path.delete_prefix("#{@dir}/")
      content = (File.read(path) rescue "")[0, MAX_FILE]
      chunk = "\n===== #{relative} =====\n#{content}\n"
      break if buffer.size + chunk.size > MAX_CHARS

      buffer << chunk
    end
    buffer
  end

  def collect_files
    prefix = "#{@dir}/"
    Dir.glob(File.join(@dir, "**", "*"), File::FNM_DOTMATCH)
       .reject { |p| File.directory?(p) }
       .map    { |p| [p, p.delete_prefix(prefix)] }
       # Skip dirs are matched as path *segments relative to the repo* — not the
       # absolute path, which lives under /tmp when cloned.
       .reject { |(_p, rel)| (SKIP_DIRS & rel.split("/")).any? }
       .select { |(p, _rel)| CODE_EXT.include?(File.extname(p).downcase) || File.basename(p).match?(/\AREADME/i) }
       .sort_by { |(p, rel)| [File.basename(p).match?(/\AREADME/i) ? 0 : 1, rel.length, rel] }
       .first(MAX_FILES)
       .map(&:first)
  end
end
