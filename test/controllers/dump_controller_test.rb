require "test_helper"

class DumpControllerTest < ActionDispatch::IntegrationTest
  test "dumps products with their latest assessment as JSON" do
    assessment = create(:assessment)
    product = assessment.product

    get dump_url(format: :json)

    assert_response :success
    body = JSON.parse(response.body)
    entry = body.find { |p| p.dig("productInfo", "name") == product.name }
    assert entry, "expected the product in the dump"
    assert_equal product.framework_or_default.name, entry.dig("productInfo", "framework")
    assert entry["cloudScore"].present?
    assert entry["capabilities"].present?
  end
end
