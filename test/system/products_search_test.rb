require "application_system_test_case"

class ProductsSearchTest < ApplicationSystemTestCase
  test "live-filters the product list by tag value via the jQuery/SJR search" do
    alpha = create(:product, name: "AlphaWidget")
    create(:tag, product: alpha, key: "city", value: "zebratag")

    beta = create(:product, name: "BetaWidget")
    create(:tag, product: beta, key: "city", value: "lionword")

    visit products_path

    # Both products listed before filtering.
    assert_text "AlphaWidget"
    assert_text "BetaWidget"

    # Typing a tag value triggers the $.ajax(dataType: 'script') live search,
    # which re-renders #products via index.js.erb.
    fill_in "search-tags", with: "zebratag"

    within "#products" do
      assert_text "AlphaWidget"
      assert_no_text "BetaWidget"
    end
  end
end
