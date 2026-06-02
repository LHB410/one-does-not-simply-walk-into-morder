import { Controller } from "@hotwired/stimulus"

// Adds/removes member rows on the sign-up form. Each row's inputs use the
// name "registration[members][][name]" so they post as an array of hashes.
export default class extends Controller {
  static targets = ["list", "template"]

  add(event) {
    event.preventDefault()
    const row = this.templateTarget.content.cloneNode(true)
    this.listTarget.appendChild(row)
  }

  remove(event) {
    event.preventDefault()
    const row = event.target.closest("[data-members-row]")
    if (row) row.remove()
  }
}
