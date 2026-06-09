import { Controller } from "@hotwired/stimulus"

// Keeps the sign-up submit button disabled until the terms-of-service checkbox
// is ticked, so the form can't be submitted without agreement. The server still
// enforces this independently — this is just the visible affordance.
export default class extends Controller {
  static targets = ["checkbox", "submit"]

  connect() {
    this.toggle()
  }

  toggle() {
    this.submitTarget.disabled = !this.checkboxTarget.checked
  }
}
