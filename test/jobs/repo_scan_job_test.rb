require "test_helper"

class RepoScanJobTest < ActiveSupport::TestCase
  setup { @product = FactoryBot.create(:product) }

  test "assesses every framework from a local repo and stores the result" do
    # The app's own checkout is a convenient local repo; the AI pass is off in
    # test, so this exercises the file detectors across both frameworks.
    scan = @product.repo_scans.create!(repo: Rails.root.to_s, status: "pending")

    RepoScanJob.perform_now(scan.id)
    scan.reload

    assert_equal "complete", scan.status
    assert_equal 100, scan.progress
    assert_equal %w[tech sre].sort, scan.models.map { |m| m["slug"] }.sort

    # Test Suite (a3) is detected at level 3 from the repo's test/ directory.
    a3 = Framework.find_by(slug: "tech").capabilities.find_by(slug: "a3")
    assert_equal 3, scan.prefill[a3.id]
  end

  test "records an error for an unresolvable repo" do
    scan = @product.repo_scans.create!(repo: "/no/such/repo", status: "pending")

    RepoScanJob.perform_now(scan.id)

    assert_equal "error", scan.reload.status
    assert scan.error.present?
  end

  test "ignores a scan that is not in progress" do
    scan = @product.repo_scans.create!(repo: Rails.root.to_s, status: "complete", progress: 100)

    RepoScanJob.perform_now(scan.id)

    assert_equal "complete", scan.reload.status, "an already-finished scan is left untouched"
  end
end
