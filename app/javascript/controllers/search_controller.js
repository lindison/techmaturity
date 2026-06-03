import { Controller } from "@hotwired/stimulus"

// Debounced live search. Lives on the search <form> (which targets the
// #products Turbo Frame); submitting the form re-renders only that frame.
export default class extends Controller {
  static values = { delay: { type: Number, default: 250 } }

  disconnect() {
    clearTimeout(this.timer)
  }

  submit() {
    clearTimeout(this.timer)
    this.timer = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }
}
