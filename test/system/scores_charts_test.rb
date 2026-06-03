require "application_system_test_case"

# Covers the Chart.js v4 charts on the scores pages (previously inline
# Chart.js v2). With js_errors: true these fail on any chart-code error, and
# the data-chart-rendered marker proves each chart actually drew.
class ScoresChartsTest < ApplicationSystemTestCase
  setup do
    @score = create(:score)
    @product = @score.product
  end

  test "scores index renders its three charts" do
    visit product_scores_path(@product)

    # category/capability live in hidden tabs, so match regardless of visibility;
    # the data-chart-rendered marker is what proves each chart actually drew.
    assert_selector "canvas#total-score-graph[data-chart-rendered='true']", visible: :all
    assert_selector "canvas#category-score-graph[data-chart-rendered='true']", visible: :all
    assert_selector "canvas#capability-score-graph[data-chart-rendered='true']", visible: :all
  end

  test "score show renders its line and bar charts" do
    visit product_score_path(@product, @score)

    assert_selector "canvas#line-score-graph[data-chart-rendered='true']"
    assert_selector "canvas#bar-score-graph[data-chart-rendered='true']"
  end
end
