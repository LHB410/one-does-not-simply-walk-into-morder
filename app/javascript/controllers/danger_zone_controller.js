import { Controller } from "@hotwired/stimulus"

// Keeps destructive account actions (e.g. closing the account) hidden behind a
// deliberate "Danger zone" toggle so they can't be clicked by accident.
export default class extends Controller {
  static targets = ["content", "chevron"]

  toggle(event) {
    event.preventDefault()
    const hidden = this.contentTarget.classList.toggle("hidden")
    if (this.hasChevronTarget) {
      this.chevronTarget.textContent = hidden ? "▸" : "▾"
    }
  }
}
