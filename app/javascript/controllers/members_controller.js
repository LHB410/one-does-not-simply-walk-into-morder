import { Controller } from "@hotwired/stimulus"

// Adds/removes member rows on the sign-up form and makes each row all-or-
// nothing: a row with any content requires BOTH name and email, while a fully
// empty row stays optional — so the leader can still sign up with no companions
// (the server drops blank rows on submit). Each row's inputs use the name
// "registration[members][][name]" so they post as an array of hashes.
export default class extends Controller {
  static targets = ["list", "template"]

  connect() {
    this.syncAll()
  }

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

  // Re-evaluate the row whose input just changed.
  sync(event) {
    this.syncRow(event.target.closest("[data-members-row]"))
  }

  // Apply the rule to every pre-rendered row (e.g. values repopulated after a
  // failed submit), so a half-filled row is flagged required on load too.
  syncAll() {
    this.listTarget
      .querySelectorAll("[data-members-row]")
      .forEach((row) => this.syncRow(row))
  }

  // A row with any value requires both fields; a blank row requires neither.
  syncRow(row) {
    if (!row) return
    const inputs = row.querySelectorAll("input")
    const started = Array.from(inputs).some((input) => input.value.trim() !== "")
    inputs.forEach((input) => { input.required = started })
  }
}
