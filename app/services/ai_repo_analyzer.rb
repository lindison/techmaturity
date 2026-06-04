require "net/http"
require "uri"
require "json"

# Uses an LLM (via OpenRouter) to score a repository's capabilities against the
# framework's actual 1-4 rubrics — the deep analysis the file-presence detectors
# can't do (e.g. Code Commenting Strategy, Code Reuse). Returns the same Finding
# struct as RepoAssessmentService so the two can be merged.
#
# The repo is read in full and split into char-bounded CHUNKS. Each chunk is
# scored independently (the "map"); the per-chunk observations are then
# reconciled into one level per capability (the "reduce") — so a large repo is
# assessed end-to-end instead of having its tail silently truncated.
class AiRepoAnalyzer
  ENDPOINT    = "https://openrouter.ai/api/v1/chat/completions"
  MODEL       = ENV.fetch("AI_ANALYSIS_MODEL", "qwen/qwen3-coder-next")

  CHUNK_CHARS = 60_000        # context budget per map call
  MAX_FILE    = 16_000        # per-file cap; larger files split into parts...
  MAX_PARTS   = 3             # ...up to this many (so one huge file can't dominate)
  MAX_FILES   = 800           # safety bound on the file list (logged if exceeded)
  MAX_CHUNKS  = 16            # safety bound on map calls (logged if exceeded)
  CONCURRENCY = 8             # parallel map calls

  SKIP_DIRS = %w[.git node_modules vendor tmp log dist build .bundle coverage .yarn target].freeze
  CODE_EXT  = %w[.rb .py .js .ts .jsx .tsx .go .java .rs .php .cs .kt .swift .scala .c .cc .cpp .h .hpp
                 .sh .sql .md .yml .yaml .tf .gradle .erb].freeze

  def self.available?
    CONFIGS[:enable_ai_analysis] && ENV["OR_DELPHI_API_KEY"].present?
  end

  # progress: optional callable invoked as (chunks_done, chunks_total) after each
  # chunk is scored, so a background job can surface live progress.
  def initialize(dir, framework, progress: nil)
    @dir = dir
    @framework = framework
    @progress = progress
  end

  # Returns an array of RepoAssessmentService::Finding (possibly empty).
  def analyze
    return [] unless self.class.available? && @framework

    parts = chunks
    return [] if parts.empty?

    observations = map_chunks(parts)
    rows = parts.size == 1 ? observations : reduce(observations)
    findings_from(rows)
  rescue => e
    Rails.logger.warn("AI repo analysis failed: #{e.class}: #{e.message}")
    []
  end

  # Exposed for testing: maps parsed rows to validated findings.
  def findings_from(rows)
    by_slug = capabilities.index_by(&:slug)
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

  # --- map: score each chunk concurrently --------------------------------------

  def map_chunks(parts)
    queue = Queue.new
    parts.each_with_index { |chunk, i| queue << [i, chunk] }
    results = Array.new(parts.size, [])
    done = 0
    lock = Mutex.new

    workers = Array.new([CONCURRENCY, parts.size].min) do
      Thread.new do
        loop do
          i, chunk = queue.pop(true) rescue break
          results[i] = begin
            parse_levels(chat(map_messages(chunk)))
          rescue => e
            Rails.logger.warn("AiRepoAnalyzer: chunk #{i + 1}/#{parts.size} failed: #{e.class}: #{e.message}")
            []
          end
          lock.synchronize { done += 1; report(done, parts.size) }
        end
      end
    end
    workers.each(&:join)
    results.flatten(1)
  end

  def report(done, total)
    @progress&.call(done, total)
  rescue => e
    Rails.logger.warn("AiRepoAnalyzer: progress callback failed: #{e.class}: #{e.message}")
  end

  # --- reduce: one level per capability from all per-chunk observations --------

  def reduce(observations)
    by_slug = capabilities.index_by(&:slug)
    summary = observations.group_by { |o| o["slug"] }.filter_map do |slug, obs|
      capability = by_slug[slug]
      next unless capability

      lines = obs.map { |o| "    - level #{o['level'].inspect}: #{o['evidence']}" }.join("\n")
      "- #{slug} — #{capability.name}:\n#{lines}"
    end.join("\n")
    return deterministic_reduce(observations) if summary.blank?

    rows = parse_levels(chat(reduce_messages(summary)))
    rows.presence || deterministic_reduce(observations)
  rescue => e
    Rails.logger.warn("AiRepoAnalyzer: reduce failed (#{e.class}: #{e.message}); using max-level fallback")
    deterministic_reduce(observations)
  end

  # Fallback reconciliation: a capability's level is the highest any chunk found
  # evidence for (presence of a more mature practice anywhere demonstrates it).
  def deterministic_reduce(observations)
    observations.group_by { |o| o["slug"] }.map do |_slug, obs|
      graded = obs.select { |o| o["level"].is_a?(Integer) }
      graded.max_by { |o| o["level"] } || obs.first
    end
  end

  # --- prompts -----------------------------------------------------------------

  def map_messages(context)
    system = "You are a staff engineer assessing PART of a code repository against a maturity model. " \
             "These files are one section of a larger codebase. For each capability you can judge from " \
             "THIS section, choose the single maturity level (1-4) best supported by these files. " \
             "OMIT capabilities for which this section shows no evidence — do not guess. Judge strictly " \
             "from what is present."

    user = "MATURITY CAPABILITIES (slug, name, and the four levels):\n#{rubric_text}\n\n" \
           "REPOSITORY FILES (one section):\n#{context}\n\n" \
           "Respond with ONLY a JSON array, one object per capability this section lets you judge:\n" \
           "[{\"slug\":\"<slug>\",\"level\":<1-4>,\"evidence\":\"<one short sentence>\"}]"

    [{ role: "system", content: system }, { role: "user", content: user }]
  end

  def reduce_messages(summary)
    system = "You are reconciling observations of a code repository into one final maturity level per " \
             "capability. Each capability lists levels seen in different sections of the codebase. Choose " \
             "the single best-supported level (1-4) per capability: weigh the strongest, most concrete " \
             "evidence, and prefer the higher level when a more mature practice is genuinely demonstrated " \
             "anywhere. Drop a capability only if no section provided real evidence."

    user = "PER-SECTION OBSERVATIONS (capability -> levels seen, with evidence):\n#{summary}\n\n" \
           "Respond with ONLY a JSON array, one object per capability:\n" \
           "[{\"slug\":\"<slug>\",\"level\":<1-4>,\"evidence\":\"<one short sentence>\"}]"

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

  # --- repo -> chunks ----------------------------------------------------------

  # Pack file segments into char-bounded chunks. No file is dropped unless the
  # MAX_CHUNKS safety bound is hit (which is logged, not silent).
  def chunks
    result = []
    current = +""
    truncated = false

    segments.each do |segment|
      if !current.empty? && current.size + segment.size > CHUNK_CHARS
        result << current
        current = +""
        if result.size >= MAX_CHUNKS
          truncated = true
          break
        end
      end
      current << segment
    end
    result << current if !truncated && !current.empty? && result.size < MAX_CHUNKS

    Rails.logger.warn("AiRepoAnalyzer: repo exceeds #{MAX_CHUNKS}-chunk budget; some files not analyzed") if truncated
    result
  end

  # Each file becomes one or more labelled "===== path =====\n<content>" blocks,
  # splitting files larger than MAX_FILE across up to MAX_PARTS parts.
  def segments
    collect_files.flat_map do |path|
      relative = path.delete_prefix("#{@dir}/")
      body = (File.read(path) rescue "")
      next [] if body.empty?

      slices = body.scan(/.{1,#{MAX_FILE}}/m).first(MAX_PARTS)
      slices.each_with_index.map do |slice, i|
        label = slices.size > 1 ? "#{relative} (part #{i + 1}/#{slices.size})" : relative
        "\n===== #{label} =====\n#{slice}\n"
      end
    end
  end

  def collect_files
    prefix = "#{@dir}/"
    files = Dir.glob(File.join(@dir, "**", "*"), File::FNM_DOTMATCH)
               .reject { |p| File.directory?(p) }
               .map    { |p| [p, p.delete_prefix(prefix)] }
               # Skip dirs are matched as path *segments relative to the repo* — not the
               # absolute path, which lives under /tmp when cloned.
               .reject { |(_p, rel)| (SKIP_DIRS & rel.split("/")).any? }
               .select { |(p, _rel)| CODE_EXT.include?(File.extname(p).downcase) || File.basename(p).match?(/\AREADME/i) }
               .sort_by { |(p, rel)| [File.basename(p).match?(/\AREADME/i) ? 0 : 1, rel.length, rel] }
               .map(&:first)

    if files.size > MAX_FILES
      Rails.logger.warn("AiRepoAnalyzer: #{files.size} candidate files; analyzing first #{MAX_FILES}")
      files = files.first(MAX_FILES)
    end
    files
  end

  def capabilities
    @capabilities ||= @framework.capabilities.includes(:capability_levels).to_a
  end

  def rubric_text
    @rubric_text ||= capabilities.map do |capability|
      levels = (1..4).map do |v|
        "    #{v}. #{capability.capability_levels.find { |l| l.value == v }&.description}"
      end.join("\n")
      "- #{capability.slug} — #{capability.name}:\n#{levels}"
    end.join("\n")
  end
end
