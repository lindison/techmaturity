require "application_system_test_case"

# The score form is now generated from the product's framework (dimensions ->
# capabilities -> levels). This locks its multi-step behavior and submission.
class ScoreFormTest < ApplicationSystemTestCase
  setup do
    @product = create(:product_with_tags) # defaults to the Tech framework
    @framework = @product.framework_or_default
    visit new_product_score_path(@product)
  end

  test "shows one step at a time and advances to the next dimension" do
    assert_selector ".progressive-form", visible: true, count: 1
    assert_selector ".progressive-form-title", text: "Code", visible: true # dimension 1

    first(:button, "Next", visible: true).click

    assert_selector ".progressive-form-title", text: "Build and Test", visible: true # dimension 2
  end

  test "selecting a level checks that capability's radio" do
    capability = @framework.capabilities.first
    cell = find(:xpath, "//input[@id='cap_#{capability.id}_2']/ancestor::td[contains(@class,'selectable')]")
    cell.click

    assert find("#cap_#{capability.id}_2", visible: :all).checked?
    assert cell[:class].include?("selected")
  end

  test "submitting the form creates an assessment for the product" do
    assert_difference -> { @product.assessments.count }, 1 do
      find("#form-submitter").click
      assert_current_path product_path(@product) # redirect on success
    end
  end
end
