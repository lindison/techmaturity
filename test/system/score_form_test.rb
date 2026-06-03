require "application_system_test_case"

# Locks the behavior of the multi-step score-entry form (scores/_form.html.erb)
# before it is ported off jQuery: progressive disclosure of one step at a time,
# selecting a level, advancing steps, and submitting to create a score.
class ScoreFormTest < ApplicationSystemTestCase
  setup do
    @product = create(:product_with_tags)
    visit new_product_score_path(@product)
    # Defensively dismiss the onboarding overlay if present so it can't
    # intercept clicks (it is disabled in the test env, belt and suspenders).
    page.execute_script("document.querySelector('.first-time-page-wrapper')?.remove()")
  end

  test "shows only the first step until the user advances" do
    # Step 1 (category "Code") is visible; step 2 (category "Build and Test")
    # is present but hidden.
    assert_selector ".progressive-form[class~='1']", text: "Code", visible: true
    assert_no_selector ".progressive-form[class~='2']", visible: true

    # Step 1 has a Next at the top and bottom (both paginate to step 2); the
    # first visible one is in the open step.
    first(:button, "Next", visible: true).click

    assert_no_selector ".progressive-form[class~='1']", visible: true

    assert_selector ".progressive-form[class~='2']", text: "Build and Test", visible: true
  end

  test "selecting a level checks that capability's radio" do
    cell = find(:xpath, "//input[@id='score_a1_2']/ancestor::td[contains(@class,'selectable')]")
    cell.click

    assert find("#score_a1_2", visible: :all).checked?
    assert cell[:class].include?("selected")
  end

  test "submitting the form creates a score for the product" do
    assert_difference -> { @product.scores.count }, 1 do
      find("#form-submitter").click
      assert_current_path product_path(@product) # redirect on success
    end
  end
end
