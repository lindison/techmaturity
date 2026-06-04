require "test_helper"

# Repo assessment now runs as a background job (the chunked LLM pass takes
# minutes), so the new-score page starts/polls a RepoScan and pre-fills once it
# completes.
class ScoreAssessmentTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "GET new with a repo starts a background scan and shows the scanning panel" do
    product = create(:product_with_tags)

    assert_enqueued_with(job: RepoScanJob) do
      get new_product_score_path(product, repo: Rails.root.to_s)
    end

    assert_response :success
    assert_select "[data-controller='repo-scan']" # the poller is on the page
    scan = product.repo_scans.last
    assert_equal "pending", scan.status
    assert_equal Rails.root.to_s, scan.repo
    assert_select "form#score-form", false, "form is hidden while the scan runs"
  end

  test "once the scan completes the form is pre-filled from it" do
    product = create(:product_with_tags)

    perform_enqueued_jobs do
      get new_product_score_path(product, repo: Rails.root.to_s)
    end
    assert product.repo_scans.last.complete?

    get new_product_score_path(product, repo: Rails.root.to_s)

    assert_response :success
    assert_select ".alert-success"
    assert_select "form#score-form"
    # Test Suite (a3) is detected at level 3, so that capability's radio is pre-checked.
    a3 = Framework.find_by(slug: "tech").capabilities.find_by(slug: "a3")
    assert_select "input#cap_#{a3.id}_3[checked]"
  end

  test "a failed scan shows an error and the manual form stays usable" do
    product = create(:product_with_tags)

    perform_enqueued_jobs do
      get new_product_score_path(product, repo: "/no/such/repo")
    end
    assert product.repo_scans.last.failed?

    get new_product_score_path(product, repo: "/no/such/repo")

    assert_response :success
    assert_select ".alert-danger"
    assert_select "form#score-form" # the manual form is still rendered
  end

  test "new score form works normally without a repo param" do
    product = create(:product_with_tags)

    get new_product_score_path(product)

    assert_response :success
    assert_select ".alert-success", false
    assert_select "[data-controller='repo-scan']", false
  end

  test "scan_status reports the scan's status and progress as JSON" do
    product = create(:product_with_tags)
    scan = product.repo_scans.create!(repo: "x", status: "running", progress: 42)

    get scan_status_product_scores_path(product, id: scan.id)

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "running", body["status"]
    assert_equal 42, body["progress"]
  end
end
