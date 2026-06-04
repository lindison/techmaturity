require "application_system_test_case"

# Guards the non-GET asset/tag actions that depend on Turbo's data-turbo-method
# (after Rails UJS was removed).
class AssetActionsTest < ApplicationSystemTestCase
  test "removing an asset deletes it" do
    product = create(:product_with_tags)

    visit product_path(product)
    accept_confirm do
      click_link "Remove Asset"
    end

    assert_current_path products_path
    assert_not Product.exists?(product.id)
  end
end
