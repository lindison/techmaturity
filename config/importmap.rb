# Pin npm packages by running ./bin/importmap

pin "application"
pin "@hotwired/turbo-rails", to: "turbo.min.js"
pin "@hotwired/stimulus", to: "stimulus.min.js"
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js"
pin_all_from "app/javascript/controllers", under: "controllers"
# jQuery and Chart.js are loaded as classic global <script>s (see the layout):
# jQuery for the legacy inline view scripts, Chart.js (UMD) for the chart views.
# They are intentionally NOT in the ES module graph (the jspm ESM builds are
# split into chunks that importmap's vendoring does not fully download).
