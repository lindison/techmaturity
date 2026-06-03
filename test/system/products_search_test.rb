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
    # which re-renders #products via index.js.erb. Use a mixed-case query to
    # guard the case-insensitive matching that PostgreSQL's LIKE doesn't give
    # for free (the stored value is lower-case "zebratag").
    fill_in "search-tags", with: "ZebraTag"

    within "#products" do
      assert_text "AlphaWidget"
      assert_no_text "BetaWidget"
    end
  end

  test "clicking a product opens its show page instead of being trapped in the search frame" do
    product = create(:product, name: "ClickableWidget")
    create(:tag, product: product, key: "city", value: "anytag")

    visit products_path
    click_link "ClickableWidget"

    # Must break out of the #products Turbo Frame (data-turbo-frame=_top),
    # otherwise Turbo renders "Content missing".
    assert_current_path product_path(product)
    assert_no_text "Content missing"
  end
end
