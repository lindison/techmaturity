require "application_system_test_case"

# The score form is now generated from the product's framework (dimensions ->
# capabilities -> levels). This locks its multi-step behavior and submission.
class ScoreFormTest < ApplicationSystemTestCase
  setup do
    @product = create(:product_with_tags) # defaults to the Tech framework
    @framework = @product.framework_or_default
    visit new_product_score_path(@product)
  end

  test "shows two dimensions per page and advances to the next pair" do
    assert_selector ".progressive-form", visible: true, count: 1
    within first(".progressive-form", visible: true) do
      assert_selector ".progressive-form-title strong", text: "Code"            # dimension 1
      assert_selector ".progressive-form-title strong", text: "Build and Test"  # dimension 2 (same page)
    end

    first(:button, "Next", visible: true).click

    within first(".progressive-form", visible: true) do
      assert_selector ".progressive-form-title strong", text: "Release" # next pair
      assert_selector ".progressive-form-title strong", text: "Operate"
    end
  end

  test "selecting a level checks that capability's radio" do
    capability = @framework.capabilities.first
    cell = find(:xpath, "//input[@id='cap_#{capability.id}_2']/ancestor::td[contains(@class,'selectable')]")
    cell.click

    assert find("#cap_#{capability.id}_2", visible: :all).checked?
    assert cell[:class].include?("selected")
  end

  test "submitting the form creates an assessment for the product" do
    # Answer one capability so the submit has something to save (an assessment is
    # created per framework that received an answer).
    capability = @framework.capabilities.first
    find(:xpath, "//input[@id='cap_#{capability.id}_2']/ancestor::td[contains(@class,'selectable')]").click

    assert_difference -> { @product.assessments.count }, 1 do
      find("#form-submitter").click
      assert_current_path product_path(@product) # redirect on success
    end
  end
end
