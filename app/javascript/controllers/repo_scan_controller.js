import { Controller } from "@hotwired/stimulus"

// Polls a background repo-scan's status endpoint and updates a progress bar.
// When the scan finishes, reloads the page so the score form renders pre-filled
// (or shows the error). Used on the new-score page while an assessment runs.
export default class extends Controller {
  static targets = ["bar", "label"]
  static values = { statusUrl: String, interval: { type: Number, default: 2500 } }

  connect() {
    this.timer = setInterval(() => this.poll(), this.intervalValue)
  }

  disconnect() {
    if (this.timer) clearInterval(this.timer)
  }

  async poll() {
    let data
    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      data = await response.json()
    } catch (_e) {
      return // transient error — try again on the next tick
    }

    if (this.hasBarTarget) this.barTarget.style.width = `${data.progress}%`
    if (this.hasLabelTarget) this.labelTarget.textContent = `${data.progress}%`

    if (data.status === "complete" || data.status === "error") {
      clearInterval(this.timer)
      window.location.reload()
    }
  }
}
