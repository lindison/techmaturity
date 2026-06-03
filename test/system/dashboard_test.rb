require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "renders the maturity dashboard and its charts without JS errors" do
    # A latest score is required for Score.summary to be present on the dashboard.
    create(:score)

    visit root_path

    # Assert the chart actually drew (renderChart marks the canvas on success),
    # not merely that the canvas element exists. With js_errors: true this also
    # proves the importmap module + Chart.js loaded and ran cleanly.
    assert_selector "canvas#category-average-graph[data-chart-rendered='true']"
  end
end
