require 'test_helper'

class ProductsFlowTest < ActionDispatch::IntegrationTest
  setup do
    @product = FactoryBot.create(:product_with_tags)
  end

  test 'should not assess not assessable products' do
    @product.update!(is_assessable: false)

    get product_url(@product)

    assert_select 'a.button--disabled[disabled="true"]'
  end
end
