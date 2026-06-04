require 'test_helper'

# "Scores" routes are backed by the Assessment model.
class ScoresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @assessment = FactoryBot.create(:assessment)
    @product = @assessment.product
    @framework = @assessment.framework
  end

  test "should get index" do
    get product_scores_url(@product)
    assert_response :success
  end

  test "should get new" do
    get new_product_score_url(@product)
    assert_response :success
  end

  test "should create an assessment from capability responses" do
    cap = @framework.capabilities.first
    assert_difference -> { @product.assessments.count }, 1 do
      post product_scores_url(@product), params: { score: { responses: { cap.id.to_s => "3" } } }
    end
    assert_redirected_to product_url(@product)
    assert_equal 3, @product.assessments.latest.first.value_for(cap)
  end

  test "should ignore capabilities outside the product's framework" do
    other = Framework.create!(name: "Other", slug: "other")
    foreign_cap = other.dimensions.create!(name: "X", slug: "x").capabilities.create!(name: "Y", slug: "y")

    post product_scores_url(@product), params: { score: { responses: { foreign_cap.id.to_s => "4" } } }

    assert_nil @product.assessments.latest.first.value_for(foreign_cap)
  end

  test "should show an assessment" do
    get product_score_url(@product, @assessment)
    assert_response :success
  end
end
