require "test_helper"

class ScoreAssessmentTest < ActionDispatch::IntegrationTest
  test "new score form pre-fills detected capabilities from a repo" do
    product = create(:product_with_tags)

    get new_product_score_path(product, repo: Rails.root.to_s)

    assert_response :success
    assert_select ".alert-success"
    # Test Suite (a3) is detected at level 3, so that radio is pre-checked.
    assert_select "input#score_a3_3[checked]"
  end

  test "new score form shows an error for an invalid repo and stays usable" do
    product = create(:product_with_tags)

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
  end
end
