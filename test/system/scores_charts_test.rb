require "application_system_test_case"

# Charts on the scores pages, now driven by Assessment data.
class ScoresChartsTest < ApplicationSystemTestCase
  setup do
    @assessment = create(:assessment) # Tech framework, all capabilities answered
    @product = @assessment.product
  end

  test "scores index renders its three charts" do
    visit product_scores_path(@product)

    # category/capability live in hidden tabs, so match regardless of visibility.
    assert_selector "canvas#total-score-graph[data-chart-rendered='true']", visible: :all
    assert_selector "canvas#category-score-graph[data-chart-rendered='true']", visible: :all
    assert_selector "canvas#capability-score-graph[data-chart-rendered='true']", visible: :all
  end

  test "score show renders its line and bar charts" do
    visit product_score_path(@product, @assessment)

    assert_selector "canvas#line-score-graph[data-chart-rendered='true']"
    assert_selector "canvas#bar-score-graph[data-chart-rendered='true']"
  end

  test "scores index nav switches the active chart tab" do
    visit product_scores_path(@product)

    assert_selector ".score-main-graph.total-score.active"

    find(".score-main-nav-item.category-score").click

    assert_selector ".score-main-graph.category-score.active"
    assert_no_selector ".score-main-graph.total-score.active"
  end
end
