import { Controller } from "@hotwired/stimulus"

// Multi-step score-entry form (ported from jQuery). Shows one step at a time,
// reveals progress bars cumulatively, and lets each capability row pick a
// single level. Lives on .progressive-form-wrapper.
export default class extends Controller {
  connect() {
    this.steps = Array.from(this.element.querySelectorAll(".progressive-form"))
    this.bars = Array.from(this.element.querySelectorAll(".progress-bar"))
    this.current = 0
    this.showStep(0)

    // Restore the selected highlight for already-checked radios (editing).
    this.element.querySelectorAll(".selectable").forEach((cell) => {
      const radio = cell.querySelector("input[type=radio]")
      if (radio && radio.checked) cell.classList.add("selected")
    })
  }

  showStep(index) {
    this.steps.forEach((step, i) => {
      step.style.display = i === index ? "" : "none"
      step.scrollTop = 0
    })
    this.bars.forEach((bar, i) => {
      bar.style.display = i <= index ? "" : "none"
    })
    this.current = index
  }

  next() {
    if (this.current < this.steps.length - 1) this.showStep(this.current + 1)
  }

  back() {
    if (this.current > 0) this.showStep(this.current - 1)
  }

  // Delegated from a click action on the wrapper. Selecting a cell always picks
  // that level (deterministic regardless of whether the label or padding was
  // clicked) and clears the other levels in the same row.
  toggleSelectable(event) {
    const cell = event.target.closest(".selectable")
    if (!cell || !this.element.contains(cell)) return

    const radio = cell.querySelector("input[type=radio]")
    if (radio) radio.checked = true

    cell.parentElement
      .querySelectorAll(".selectable")
      .forEach((sibling) => sibling.classList.remove("selected"))
    cell.classList.add("selected")
  }
}
