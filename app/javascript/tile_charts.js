// Renders the per-product "maturity" doughnut charts (canvas.tile-score-chart).
// Each canvas carries its score in data-percentage. Re-runs on full Turbo
// visits and when the products Turbo Frame is replaced by a search.

const colorFor = (pct) => (pct < 40 ? "#F00" : pct < 80 ? "#FA3" : "#19AB20")

// Chart.js v4 plugin: draw the percentage in the centre of the doughnut.
const centerTextPlugin = {
  id: "centerText",
  afterDraw(chart) {
    const text = chart.options.plugins.centerText?.text
    if (!text) return
    const { ctx, chartArea: { left, right, top, bottom } } = chart
    ctx.save()
    ctx.font = "16px 'Helvetica Neue', 'Helvetica', 'Arial', sans-serif"
    ctx.fillStyle = "#000"
    ctx.textAlign = "center"
    ctx.textBaseline = "middle"
    ctx.fillText(text, (left + right) / 2, (top + bottom) / 2)
    ctx.restore()
  }
}

const drawTile = (canvas) => {
  const pct = parseFloat(canvas.dataset.percentage) || 0
  window.renderChart(canvas, {
    type: "doughnut",
    data: {
      datasets: [{
        data: [pct, 100 - pct],
        backgroundColor: [colorFor(pct), "#F6F7F9"],
        borderWidth: 0
      }]
    },
    options: {
      responsive: false,
      animation: false,
      plugins: {
        legend: { display: false },
        tooltip: { enabled: false },
        centerText: { text: `${pct.toFixed(2)}%` }
      }
    },
    plugins: [centerTextPlugin]
  })
}

const initTileCharts = (root = document) =>
  root.querySelectorAll(".tile-score-chart").forEach(drawTile)

document.addEventListener("turbo:load", () => initTileCharts())
document.addEventListener("turbo:frame-load", (event) => initTileCharts(event.target))
