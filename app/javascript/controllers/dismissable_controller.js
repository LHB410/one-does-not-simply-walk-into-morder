import { Controller } from "@hotwired/stimulus"

// Closes a popup by removing its element from the DOM. Replaces inline
// `onclick` handlers, which the enforced CSP (no 'unsafe-inline' + a nonce on
// script-src) blocks.
export default class extends Controller {
  close() {
    this.element.remove()
  }
}
