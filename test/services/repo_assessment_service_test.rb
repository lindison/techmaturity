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
end
