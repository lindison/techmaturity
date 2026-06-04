require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "renders the maturity dashboard and its charts without JS errors" do
    # A latest assessment in the (default Tech) framework gives the dashboard data.
    create(:assessment)

    visit root_path

    # Assert the chart actually drew (renderChart marks the canvas on success),
    # not merely that the canvas element exists. With js_errors: true this also
    # proves the importmap module + Chart.js loaded and ran cleanly.
    assert_selector "canvas#category-average-graph[data-chart-rendered='true']"
  end
end
