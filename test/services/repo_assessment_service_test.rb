require "test_helper"

class RepoAssessmentServiceTest < ActiveSupport::TestCase
  test "detects capabilities from a local repository path" do
    result = RepoAssessmentService.assess(Rails.root.to_s)

    assert_nil result.error
    assert_equal 3, result.scores["a3"],  "test suite (test/ dir)"
    assert_equal 3, result.scores["c8"],  "dependency lockfile (Gemfile.lock)"
    assert_equal 3, result.scores["c10"], "db migrations (db/migrate)"
    assert result.scores["c1"], "containerized deployment (Dockerfile)"
    assert(result.findings.all? { |f| (1..4).cover?(f.level) })
    assert(result.findings.all? { |f| f.note.present? })
  end

  test "leaves org/process capabilities unscored (not inferable from source)" do
    result = RepoAssessmentService.assess(Rails.root.to_s)

    refute result.scores.key?("d4"), "on-call strategy"
    refute result.scores.key?("e1"), "continuous process improvement"
  end

  test "returns an error for a path that does not exist" do
    result = RepoAssessmentService.assess("/no/such/repo")

    assert result.error
    assert_empty result.scores
  end

  test "returns an error for blank input" do
    assert RepoAssessmentService.assess("").error
  end

  test "detects SRE signals when assessing with the SRE framework" do
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "monitoring"))
      File.write(File.join(dir, "monitoring/prometheus.yml"), "scrape_configs: []")
      File.write(File.join(dir, "monitoring/app.rules.yml"), "groups:\n- rules:\n  - alert: HighErrorRate")
      FileUtils.mkdir_p(File.join(dir, "grafana"))
      File.write(File.join(dir, "grafana/overview.json"), "{}")
      File.write(File.join(dir, "main.tf"), "resource \"null_resource\" \"x\" {}")

      result = RepoAssessmentService.assess(dir, framework: "sre")

      assert_nil result.error
      assert result.scores["golden_signals"], "prometheus -> golden signals"
      assert result.scores["dashboards"], "grafana -> dashboards"
      assert result.scores["alerting"], "rules -> alerting"
      assert result.scores["automation"], "terraform -> automation"
      refute result.scores.key?("a3"), "should not return Tech slugs for the SRE framework"
    end
  end

  test "accepts any git URL (no host filtering)" do
    # A well-formed but unreachable URL is attempted and fails to clone — it is
    # never rejected for being internal/private; any repo URL is allowed.
    result = RepoAssessmentService.assess("https://git.internal.example/team/repo.git")
    assert_no_match(/internal|private|loopback|metadata|refus/i, result.error.to_s)
  end
end

