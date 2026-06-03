require 'test_helper'

class ProductTest < ActiveSupport::TestCase

  test "does not return is_active=false" do
    p = FactoryBot.create(:product_with_tags)
    p.is_active = false
    p.save
    assert_raises(ActiveRecord::RecordNotFound) { Product.find p.id }
  end

  test "returns when is_sctive=true" do
    p = FactoryBot.create(:product_with_tags)
    assert_equal(p.is_active, true)
    Product.find p.id
  end

  test "tag search is case-insensitive (PostgreSQL LIKE is case-sensitive)" do
    product = FactoryBot.create(:product, name: "AlphaWidget")
    FactoryBot.create(:tag, product: product, key: "city", value: "zebratag")

    results = Product.search_products("ZebraTag", "", 1)

    assert_includes results.map(&:id), product.id
  end

end
