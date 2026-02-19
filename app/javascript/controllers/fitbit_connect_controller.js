import { Controller } from "@hotwired/stimulus"

// Updates the Fitbit connect link with the browser's timezone.
export default class extends Controller {
  connect() {
    const link = this.element
    if (!link) return

    const tz = Intl.DateTimeFormat().resolvedOptions().timeZone
    if (!tz) return

    try {
      const url = new URL(link.href, window.location.origin)
      url.searchParams.set("timezone", tz)
      link.href = url.toString()
    } catch (_) {
      // If URL parsing fails for any reason, just leave the link as-is.
    }
  }
}

