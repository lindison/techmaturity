require "test_helper"
require "capybara/cuprite"

# Drive a real headless Chromium over CDP (Ferrum/Cuprite). `js_errors: true`
# makes any uncaught JS error fail the test, so these specs guard the legacy
# jQuery + Chart.js front-end against regressions (e.g. a future importmap /
# Hotwire migration that breaks asset loading).
#
# Options must be passed through `driven_by(options:)` because Rails'
# SystemTestCase re-registers the :cuprite driver itself (a top-level
# Capybara.register_driver block would be overridden and ignored).
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :cuprite, screen_size: [1400, 1400], options: {
    browser_path: ENV.fetch("CHROMIUM_PATH", "/usr/bin/chromium-browser"),
    browser_options: {
      "headless" => "new",
      "no-sandbox" => nil,
      "disable-gpu" => nil,
      "disable-software-rasterizer" => nil,
      "disable-dev-shm-usage" => nil
    },
    process_timeout: 60,
    timeout: 30,
    js_errors: true
  }
end
