require "test_helper"

class RepoScanTest < ActiveSupport::TestCase
  setup { @product = FactoryBot.create(:product) }

  test "status predicates reflect the lifecycle" do
    scan = @product.repo_scans.new(repo: "x", status: "pending")
    assert scan.in_progress?
    refute scan.complete?
    refute scan.failed?

    scan.status = "running"
    assert scan.in_progress?

    scan.status = "complete"
    assert scan.complete?
    refute scan.in_progress?

    scan.status = "error"
    assert scan.failed?
    refute scan.in_progress?
  end

  test "stale? only when in progress and untouched past the window" do
    scan = @product.repo_scans.create!(repo: "x", status: "running")
    refute scan.stale?, "a fresh running scan is not stale"

    scan.update_column(:updated_at, (RepoScan::STALE_AFTER + 1.minute).ago)
    assert scan.reload.stale?, "a long-running scan is treated as dead"

    scan.update!(status: "complete")
    refute scan.stale?, "a finished scan is never stale"
  end

  test "prefill/models/source read from the result JSON" do
    scan = @product.repo_scans.create!(repo: "git@host:r.git", status: "complete", result: {
      "prefill" => { "5" => 3, "9" => 4 },
      "models"  => [{ "name" => "Tech", "slug" => "tech", "findings" => [] }],
      "source"  => "git@host:r.git"
    })

    assert_equal({ 5 => 3, 9 => 4 }, scan.prefill, "string keys become capability ids")
    assert_equal 1, scan.models.size
    assert_equal "git@host:r.git", scan.source
  end

  test "source falls back to the repo when the result has none" do
    scan = @product.repo_scans.create!(repo: "myrepo", status: "pending")

    assert_equal "myrepo", scan.source
    assert_equal({}, scan.prefill)
    assert_equal [], scan.models
  end
end
