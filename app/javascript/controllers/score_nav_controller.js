import { Controller } from "@hotwired/stimulus"

// Tab switching for the scores index trending charts (ported from jQuery).
// Each .score-main-nav-item[data-item] activates the matching .score-main-graph.
export default class extends Controller {
  select(event) {
    const item = event.target.closest(".score-main-nav-item")
    if (!item || !this.element.contains(item)) return

    this.element
      .querySelectorAll(".score-main-nav-item.active, .score-main-graph.active")
      .forEach((el) => el.classList.remove("active"))

    item.classList.add("active")
    const graph = this.element.querySelector(`.score-main-graph.${item.dataset.item}`)
    if (graph) graph.classList.add("active")
  }
}
