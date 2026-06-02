import { Controller } from "@hotwired/stimulus"

// Logged-out entry screen. "Log in" hides the choices and reveals the existing
// login modal; "Sign up" is a plain link handled by the browser.
export default class extends Controller {
  static targets = ["choices", "login"]

  showLogin(event) {
    event.preventDefault()
    this.choicesTarget.classList.add("hidden")
    this.loginTarget.classList.remove("hidden")
  }
}
