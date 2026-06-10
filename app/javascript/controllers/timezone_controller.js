import { Controller } from "@hotwired/stimulus"

// Fills a hidden field with the browser's IANA timezone.
export default class extends Controller {
  connect() {
    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (tz) this.element.value = tz
  }
}
