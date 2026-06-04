require "open3"
require "tmpdir"
require "fileutils"
require "uri"
require "resolv"
require "ipaddr"

# Inspects a code repository (a local path or a git URL) and infers maturity
# levels (1-4) for the capabilities that leave detectable signals in source.
# Org/process capabilities (on-call, runbooks adoption, definition of done, ...)
# can't be inferred and are left for a human to fill in.
#
# Usage:
#   result = RepoAssessmentService.assess("https://github.com/owner/repo")
#   result.scores    # => { "a3" => 3, "b5" => 1, "c8" => 3, ... }
#   result.findings  # => [#<Finding key="a3" title="Test Suite" level=3 note="...">, ...]
#   result.error     # => nil or a message
class RepoAssessmentService
  Finding = Struct.new(:key, :title, :level, :note, keyword_init: true)
  Result  = Struct.new(:source, :scores, :findings, :error, keyword_init: true)

  CAPABILITY_TITLES = {
    "a3"  => "Test Suite",
    "a4"  => "Logging and Telemetry",
    "a12" => "Behavior Driven Development (BDD)",
    "b2"  => "Code Quality",
    "b3"  => "Security Code Analysis",
    "b4"  => "Automated Testing",
    "b5"  => "Continuous Integration",
    "c1"  => "Deployment Strategy",
    "c2"  => "Release Frequency",
    "c3"  => "Feature Flags",
    "c7"  => "Deployment Methodology",
    "c8"  => "Dependency Management",
    "c10" => "Scriptable DB Releases",
    "d2"  => "Runbook Adoption"
  }.freeze

  GIT_URL = %r{\A(https?://|git@[\w.-]+:|ssh://)}

  def self.assess(location)
    new(location).assess
  end

  def initialize(location)
    @location = location.to_s.strip
  end

  def assess
    dir, cleanup, error = resolve_working_dir
    return Result.new(source: @location, scores: {}, findings: [], error: error) if error

    @dir = dir
    findings = CAPABILITY_TITLES.keys.filter_map do |key|
      result = send("detect_#{key}")
      next unless result

      level, note = result
      Finding.new(key: key, title: CAPABILITY_TITLES[key], level: level, note: note)
    end
    Result.new(source: @location, scores: findings.to_h { |f| [f.key, f.level] }, findings: findings, error: nil)
  ensure
    FileUtils.remove_entry(dir) if cleanup && dir && Dir.exist?(dir)
  end

  private

  def resolve_working_dir
    if @location.empty?
      [nil, false, "No repository given"]
    elsif @location.match?(GIT_URL)
      return [nil, false, "Refusing to clone an internal/private host"] if internal_host?(@location)

      clone_repo
    elsif File.directory?(@location)
      [File.expand_path(@location), false, nil]
    else
      [nil, false, "Not a git URL or an existing directory: #{@location}"]
    end
  end

  # SSRF guard: reject URLs whose host resolves to loopback, link-local
  # (incl. the cloud metadata IP), or private ranges.
  PRIVATE_RANGES = [
    "127.0.0.0/8", "0.0.0.0/8", "10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16",
    "169.254.0.0/16", "::1/128", "fc00::/7", "fe80::/10"
  ].map { |r| IPAddr.new(r) }.freeze

  def internal_host?(location)
    host = git_host(location)
    return true if host.nil? || host.empty?

    addresses = Resolv.getaddresses(host)
    return true if addresses.empty?

    addresses.any? { |ip| ip_internal?(ip) }
  rescue StandardError
    true # fail closed
  end

  def git_host(location)
    if (m = location.match(/\Agit@([^:]+):/))
      m[1]
    else
      URI.parse(location).host
    end
  end

  def ip_internal?(ip)
    addr = IPAddr.new(ip)
    PRIVATE_RANGES.any? { |range| range.include?(addr) }
  rescue IPAddr::Error
    true
  end

  def clone_repo
    dir = Dir.mktmpdir("repo-assess-")
    # No prompts (fail fast on private/bad URLs); shallow clone; `--` guards
    # against a URL being read as an option.
    env = { "GIT_TERMINAL_PROMPT" => "0", "GIT_ASKPASS" => "/bin/true" }
    _out, status = Open3.capture2e(env, "git", "clone", "--depth", "1", "--quiet", "--", @location, dir)
    return [dir, true, nil] if status.success?

    FileUtils.remove_entry(dir)
    [nil, false, "Could not clone repository (private, unreachable, or invalid URL)"]
  rescue Errno::ENOENT
    [nil, false, "git is not installed in this environment"]
  rescue => e
    [nil, false, "Clone failed: #{e.message}"]
  end

  # --- detection helpers ---

  # True if any of the (case-insensitive) glob patterns match a file/dir.
  def any?(*patterns)
    patterns.any? { |p| Dir.glob(File.join(@dir, p), File::FNM_CASEFOLD | File::FNM_DOTMATCH).any? }
  end

  def count(*patterns)
    patterns.sum { |p| Dir.glob(File.join(@dir, p), File::FNM_CASEFOLD | File::FNM_DOTMATCH).count { |f| File.file?(f) } }
  end

  # Lower-cased contents of common dependency manifests, concatenated.
  def deps
    @deps ||= %w[Gemfile package.json requirements.txt Pipfile pyproject.toml go.mod
                 build.gradle build.gradle.kts pom.xml composer.json Cargo.toml]
              .map { |f| File.join(@dir, f) }
              .select { |path| File.file?(path) }
              .map { |path| File.read(path) rescue "" }
              .join("\n").downcase
  end

  # --- detectors (each returns [level, note] or nil to skip) ---

  def detect_a3 # Test Suite
    n = count("{test,tests,spec,__tests__}/**/*_*.rb", "{test,tests,spec,__tests__}/**/*.{py,js,ts,go,java,rb}",
              "**/*_{test,spec}.{rb,py,js,ts,go}", "**/test_*.py", "**/*.{test,spec}.{js,ts,jsx,tsx}")
    return [1, "No test files found"] if n.zero?
    return [3, "#{n} test files in a dedicated test directory"] if any?("test/*", "tests/*", "spec/*")

    [2, "#{n} test files found"]
  end

  def detect_b4 # Automated Testing (tests gated by CI)
    has_tests = (detect_a3&.first || 1) >= 2
    has_ci = !detect_b5.nil?
    return [3, "Tests run in an automated pipeline"] if has_tests && has_ci
    return [2, "Tests present but no CI pipeline detected"] if has_tests

    [1, "No automated tests detected"]
  end

  def detect_b5 # Continuous Integration
    return [3, "CI configuration present"] if any?(
      ".github/workflows/*.{yml,yaml}", ".gitlab-ci.yml", "Jenkinsfile",
      ".circleci/config.yml", ".travis.yml", "azure-pipelines.yml", "bitbucket-pipelines.yml", ".drone.yml"
    )

    nil # no signal -> leave for human
  end

  def detect_b2 # Code Quality (linters/formatters)
    return [3, "Linter/formatter configuration present"] if any?(
      ".rubocop.yml", ".eslintrc*", ".flake8", ".pylintrc", "tslint.json", ".golangci.{yml,yaml}",
      "checkstyle.xml", ".prettierrc*", ".editorconfig", "setup.cfg", "ruff.toml"
    )

    nil
  end

  def detect_b3 # Security Code Analysis
    sast = any?(".snyk", ".github/dependabot.{yml,yaml}", ".semgrep.yml") ||
           deps.include?("brakeman") || deps.include?("bandit") ||
           Dir.glob(File.join(@dir, ".github/workflows/*.{yml,yaml}"), File::FNM_CASEFOLD)
              .any? { |f| (File.read(f) rescue "").match?(/codeql|snyk|trivy|semgrep|brakeman|bandit/i) }
    sast ? [3, "Static security analysis configured"] : nil
  end

  def detect_c1 # Deployment Strategy (containerization/orchestration)
    return [3, "Containerized / orchestrated deployment"] if any?(
      "Dockerfile", "**/Dockerfile", "docker-compose*.{yml,yaml}", "Chart.yaml", "**/Chart.yaml", "k8s/**", "kubernetes/**"
    )

    nil
  end

  def detect_c7 # Deployment Methodology (Infrastructure as Code)
    return [3, "Infrastructure-as-code present"] if any?(
      "**/*.tf", "**/*.bicep", "ansible/**", "*playbook*.{yml,yaml}", "cloudformation/**", "Pulumi.yaml"
    )

    nil
  end

  def detect_c8 # Dependency Management
    return [4, "Automated dependency updates configured"] if any?(".github/dependabot.{yml,yaml}", "renovate.json", ".renovaterc*")
    return [3, "Pinned dependencies via a lockfile"] if any?(
      "Gemfile.lock", "package-lock.json", "yarn.lock", "pnpm-lock.yaml", "poetry.lock",
      "Pipfile.lock", "go.sum", "Cargo.lock", "composer.lock"
    )
    return [2, "Dependency manifest present but unpinned"] unless deps.empty?

    nil
  end

  def detect_c10 # Scriptable DB Releases (migrations)
    return [3, "Database migrations present"] if any?(
      "db/migrate/*", "**/migrations/*", "**/migrate/*", "**/*flyway*", "**/changelog*.xml", "alembic/**"
    )

    nil
  end

  def detect_a12 # BDD
    any?("**/*.feature") ? [3, "Gherkin/BDD feature files present"] : nil
  end

  def detect_c3 # Feature Flags
    %w[launchdarkly flipper unleash flagsmith split.io ld-relay].any? { |lib| deps.include?(lib) } ?
      [3, "Feature-flag library in dependencies"] : nil
  end

  def detect_a4 # Logging and Telemetry
    %w[lograge winston log4j logback structlog zap serilog opentelemetry datadog sentry].any? { |lib| deps.include?(lib) } ?
      [3, "Logging/telemetry library in dependencies"] : nil
  end

  def detect_d2 # Runbook Adoption
    return [3, "Runbook documentation present"] if any?("**/runbook*", "**/RUNBOOK*", "docs/runbook*")
    return [2, "A docs/ directory is present"] if any?("docs/*")

    nil
  end

  def detect_c2 # Release Frequency (from git tags)
    return nil unless File.directory?(File.join(@dir, ".git"))

    out, status = Open3.capture2e("git", "-C", @dir, "tag")
    return nil unless status.success?

    tags = out.split("\n").reject(&:empty?).size
    return nil if tags.zero?
    return [4, "#{tags} release tags"] if tags >= 20
    return [3, "#{tags} release tags"] if tags >= 5

    [2, "#{tags} release tag(s)"]
  rescue Errno::ENOENT
    nil # git not installed in this environment
  end
end
