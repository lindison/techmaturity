require 'test_helper'

class DataManagementTest < ActionDispatch::IntegrationTest
  test "data page renders with the application count" do
    get data_path
    assert_response :success
    assert_select "#product-count"
  end

  test "load_sample creates the Infoblox demo applications" do
    assert_difference -> { Product.unscoped.count }, SampleDataService::INFOBLOX_APPS.size do
      post load_sample_path
    end
    assert_redirected_to data_path
    assert Product.unscoped.exists?(name: "BloxOne DDI")
  end

  test "reset with the correct PIN clears all data" do
    SampleDataService.load_infoblox!
    assert Product.unscoped.count.positive?

    post reset_data_path, params: { pin: "8805" }

    assert_redirected_to data_path
    assert_equal 0, Product.unscoped.count
    assert_equal 0, Assessment.count
    assert_equal 0, Tag.count
  end

  test "reset with the wrong PIN leaves data intact" do
    SampleDataService.load_infoblox!
    before = Product.unscoped.count
    assert before.positive?

    post reset_data_path, params: { pin: "0000" }

    assert_equal before, Product.unscoped.count
  end

  test "dashboard shows an empty state when there is no data" do
    Product.unscoped.destroy_all

    get root_path

    assert_response :success
    assert_select "a", text: "Manage data"
  end
end
