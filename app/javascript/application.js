// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// jQuery and Chart.js (UMD) are loaded as classic global scripts in the layout,
// so window.Chart / window.$ are available to this module and to legacy inline
// view scripts.

// Idempotent chart helper: safe to call repeatedly across Turbo navigations
// (destroys any chart already bound to the canvas before drawing a new one).
window.renderChart = (idOrEl, config) => {
  const el = typeof idOrEl === "string" ? document.getElementById(idOrEl) : idOrEl
  if (!el) return null
  window.Chart.getChart(el)?.destroy()
  const chart = new window.Chart(el, config)
  el.setAttribute("data-chart-rendered", "true") // lets system tests assert it drew
  return chart
}

import "./tile_charts"
