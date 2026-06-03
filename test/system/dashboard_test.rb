require "application_system_test_case"

class DashboardTest < ApplicationSystemTestCase
  test "renders the maturity dashboard and its charts without JS errors" do
    # A latest score is required for Score.summary to be present on the dashboard.
    create(:score)

    visit root_path

    # The aggregate category chart canvas is rendered by the Chart.js view code.
    assert_selector "canvas#category-average-graph"
    # Reaching here with js_errors: true means jQuery + Chart.js loaded and the
    # chart-init code ran cleanly.
  end
end
