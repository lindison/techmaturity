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

  test "routes each response to its own framework's assessment (one process, many models)" do
    tech_cap = Framework.find_by(slug: "tech").capabilities.first
    sre_cap  = Framework.find_by(slug: "sre").capabilities.first

    assert_difference -> { @product.assessments.count }, 2 do
      post product_scores_url(@product), params: { score: { responses: {
        tech_cap.id.to_s => "3", sre_cap.id.to_s => "4"
      } } }
    end

    tech = @product.assessments.latest.find_by(framework: tech_cap.dimension.framework)
    sre  = @product.assessments.latest.find_by(framework: sre_cap.dimension.framework)
    assert_equal 3, tech.value_for(tech_cap)
    assert_equal 4, sre.value_for(sre_cap)
    assert_nil tech.value_for(sre_cap), "a framework's assessment only holds its own capabilities"
  end

  test "should show an assessment" do
    get product_score_url(@product, @assessment)
    assert_response :success
  end
end
