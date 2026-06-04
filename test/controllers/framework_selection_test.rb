require "test_helper"

class FrameworkSelectionTest < ActionDispatch::IntegrationTest
  test "a product can be assessed against the SRE framework" do
    sre = Framework.find_by(slug: "sre")
    product = Product.create!(name: "SRE App", product_type: "Product", framework: sre)

    get new_product_score_path(product)
    assert_response :success
    assert_select ".progressive-form-title", text: "SLOs & Error Budgets" # an SRE dimension

    capability = sre.capabilities.find_by(slug: "error_budget")
    assert_difference -> { product.assessments.count }, 1 do
      post product_scores_path(product), params: { score: { responses: { capability.id.to_s => "4" } } }
    end

    assessment = product.assessments.latest.first
    assert_equal sre, assessment.framework
    assert_equal 4, assessment.value_for(capability)
  end

  test "frameworks expose their dimensions and capabilities" do
    sre = Framework.find_by(slug: "sre")
    assert_equal 5, sre.dimensions.count
    assert_equal 25, sre.capabilities.count
    assert sre.capabilities.all? { |c| c.capability_levels.count == 4 }
  end
end
