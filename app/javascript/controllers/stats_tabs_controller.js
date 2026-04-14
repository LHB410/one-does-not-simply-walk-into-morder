import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  selectTab(event) {
    const index = parseInt(event.currentTarget.dataset.tabIndex)

    this.tabTargets.forEach((tab, i) => {
      if (i === index) {
        tab.classList.add("border-yellow-500", "text-yellow-500")
        tab.classList.remove("border-transparent", "text-gray-400")
        tab.setAttribute("aria-selected", "true")
      } else {
        tab.classList.remove("border-yellow-500", "text-yellow-500")
        tab.classList.add("border-transparent", "text-gray-400")
        tab.setAttribute("aria-selected", "false")
      }
    })

    this.panelTargets.forEach((panel, i) => {
      panel.classList.toggle("hidden", i !== index)
    })
  }
}
