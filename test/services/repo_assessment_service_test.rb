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

  test "refuses loopback and cloud-metadata hosts (SSRF guard)" do
    [
      "http://127.0.0.1/x.git",
      "https://localhost/repo.git",
      "http://169.254.169.254/latest/meta-data/" # cloud metadata
    ].each do |url|
      result = RepoAssessmentService.assess(url)
      assert result.error, "expected #{url} to be rejected"
      assert_match(/loopback|metadata/i, result.error)
    end
  end

  test "does not block internal/private git hosts (so internal repos can be assessed)" do
    # The SSRF guard must NOT flag RFC1918 hosts — assessing internal/enterprise
    # git servers is the point. (We check the guard, not a real clone.)
    service = RepoAssessmentService.new("https://git.internal.example/team/repo.git")
    %w[10.0.0.5 172.16.4.4 192.168.1.10].each do |ip|
      assert_not service.send(:ip_blocked?, ip), "#{ip} should be allowed"
    end
    assert service.send(:ip_blocked?, "169.254.169.254"), "metadata IP should be blocked"
    assert service.send(:ip_blocked?, "127.0.0.1"), "loopback should be blocked"
  end
end

