require "open3"
require "tmpdir"
require "fileutils"

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

  # Per-framework detector sets: [capability slug, title, detector method].
  DETECTORS = {
    "tech" => [
      ["a3",  "Test Suite",                        :detect_a3],
      ["a12", "Behavior Driven Development (BDD)",  :detect_a12],
      ["b2",  "Code Quality",                       :detect_b2],
      ["b3",  "Security Code Analysis",             :detect_b3],
      ["b4",  "Automated Testing",                  :detect_b4],
      ["b5",  "Continuous Integration",             :detect_b5],
      ["c1",  "Deployment Strategy",                :detect_c1],
      ["c2",  "Release Frequency",                  :detect_c2],
      ["c3",  "Feature Flags",                      :detect_c3],
      ["c7",  "Deployment Methodology",             :detect_c7],
      ["c8",  "Dependency Management",              :detect_c8],
      ["c10", "Scriptable DB Releases",             :detect_c10],
      ["d2",  "Runbook Adoption",                   :detect_d2]
    ],
    "sre" => [
      ["slo",                 "Service Level Objectives",  :detect_slo],
      ["golden_signals",      "Four Golden Signals",       :detect_metrics],
      ["dashboards",          "Dashboards",                :detect_dashboards],
      ["alerting",            "Symptom-based Alerting",     :detect_alerting],
      ["logging",             "Logging",                    :detect_logging_stack],
      ["tracing",             "Distributed Tracing",        :detect_tracing],
      ["release_engineering", "Release Engineering",        :detect_release_engineering],
      ["automation",          "Operational Automation",     :detect_automation],
      ["reliability_testing", "Testing for Reliability",    :detect_chaos],
      ["dr",                  "Disaster Recovery",          :detect_dr],
      ["postmortem",          "Blameless Postmortems",      :detect_postmortems]
    ]
  }.freeze

  GIT_URL = %r{\A(https?://|git@[\w.-]+:|ssh://)}

  def self.assess(location, framework: "tech", progress: nil)
    new(location, framework, progress: progress).assess
  end

  def initialize(location, framework = "tech", progress: nil)
    @location = location.to_s.strip
    @framework = framework.to_s
    @progress = progress
  end

  def assess
    dir, cleanup, error = resolve_working_dir
    return Result.new(source: @location, scores: {}, findings: [], error: error) if error

    @dir = dir
    findings = merge_findings(file_detector_findings, ai_findings)
    Result.new(source: @location, scores: findings.to_h { |f| [f.key, f.level] }, findings: findings, error: nil)
  ensure
    FileUtils.remove_entry(dir) if cleanup && dir && Dir.exist?(dir)
  end

  private

  def detectors
    DETECTORS[@framework] || DETECTORS["tech"]
  end

  def file_detector_findings
    detectors.filter_map do |slug, title, method|
      result = send(method)
      next unless result

      level, note = result
      Finding.new(key: slug, title: title, level: level, note: note)
    end
  end

  # Deep LLM analysis against the framework's rubrics (when configured).
  def ai_findings
    return [] unless AiRepoAnalyzer.available?

    framework = Framework.find_by(slug: @framework)
    framework ? AiRepoAnalyzer.new(@dir, framework, progress: @progress).analyze : []
  end

  # AI findings (deeper) take precedence over file-detector findings by slug.
  def merge_findings(file, ai)
    ai_by_slug = ai.index_by(&:key)
    overridden = file.map { |f| ai_by_slug.delete(f.key) || f }
    overridden + ai_by_slug.values
  end

  private

  def resolve_working_dir
    if @location.empty?
      [nil, false, "No repository given"]
    elsif @location.match?(GIT_URL)
      clone_repo
    elsif File.directory?(@location)
      [File.expand_path(@location), false, nil]
    else
      [nil, false, "Not a git URL or an existing directory: #{@location}"]
    end
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

  # True if any matching file's contents match the pattern (bounded scan).
  def grep?(pattern, *globs)
    globs.any? do |g|
      Dir.glob(File.join(@dir, g), File::FNM_CASEFOLD).first(200).any? do |f|
        File.file?(f) && (File.read(f) rescue "").match?(pattern)
      end
    end
  end

  # --- SRE detectors (each returns [level, note] or nil) ---

  def detect_slo # Service Level Objectives
    return [4, "SLO definitions with error budgets"] if grep?(/error.?budget/i, "**/*.slo.{yml,yaml}", "**/slo*.{yml,yaml}")
    return [3, "SLO definitions present"] if any?("**/*.slo.{yml,yaml}", "**/slo/**", "**/sloth*.{yml,yaml}") || deps.include?("openslo")

    nil
  end

  def detect_metrics # Four Golden Signals (Prometheus/metrics)
    return [3, "Prometheus / metrics instrumentation present"] if any?(
      "**/prometheus.{yml,yaml}", "**/prometheus/**", "**/servicemonitor*.{yml,yaml}"
    ) || %w[prom-client prometheus_client micrometer prometheus-client].any? { |l| deps.include?(l) }

    nil
  end

  def detect_dashboards # Dashboards
    any?("**/grafana/**", "**/dashboards/*.json", "**/*dashboard*.json") ? [3, "Grafana/dashboard definitions present"] : nil
  end

  def detect_alerting # Symptom-based Alerting
    return [3, "Alerting rules present"] if any?("**/*.rules.{yml,yaml}", "**/alertmanager*.{yml,yaml}", "**/alerts/**") ||
                                            grep?(/kind:\s*PrometheusRule|alert:\s/i, "**/*.{yml,yaml}")

    nil
  end

  def detect_logging_stack # Logging
    return [3, "Centralized logging configuration present"] if any?(
      "**/fluent*.conf", "**/fluent-bit*.{conf,yaml}", "**/logstash*.{conf,yml,yaml}", "**/vector.{toml,yaml}"
    ) || %w[lograge fluentd logstash serilog structlog winston].any? { |l| deps.include?(l) }

    nil
  end

  def detect_tracing # Distributed Tracing
    return [3, "Distributed tracing instrumentation present"] if any?("**/otel-collector*.{yml,yaml}", "**/jaeger*.{yml,yaml}") ||
                                                                 %w[opentelemetry jaeger zipkin opentracing].any? { |l| deps.include?(l) }

    nil
  end

  def detect_release_engineering # Release Engineering
    gitops = any?("**/argocd/**", "**/flux/**", "**/.argo*/**") || grep?(/argo|flux|spinnaker/i, ".github/workflows/*.{yml,yaml}")
    canary = any?("**/rollout*.{yml,yaml}") || %w[flagger argo-rollouts].any? { |l| deps.include?(l) }
    return [4, "Progressive delivery (canary/rollouts) configured"] if canary
    return [3, "GitOps / CD pipeline present"] if gitops
    return [2, "CI pipeline present"] if detect_b5

    nil
  end

  def detect_automation # Operational Automation (IaC)
    detect_c7 ? [3, "Infrastructure-as-code / automation present"] : nil
  end

  def detect_chaos # Testing for Reliability (chaos engineering)
    return [3, "Chaos / resilience testing tooling present"] if any?("**/chaos/**", "**/*chaos*.{yml,yaml}") ||
                                                                %w[litmus chaostoolkit gremlin chaos-mesh].any? { |l| deps.include?(l) }

    nil
  end

  def detect_dr # Disaster Recovery
    return [3, "Backup / disaster-recovery configuration present"] if any?(
      "**/velero/**", "**/backup*.{yml,yaml,sh}", "**/*restore*.{yml,yaml,sh}"
    ) || deps.include?("velero")

    nil
  end

  def detect_postmortems # Blameless Postmortems
    any?("**/postmortem*", "**/post-mortem*", "docs/incidents/**", "**/incident*report*") ? [3, "Postmortem / incident documentation present"] : nil
  end
end
