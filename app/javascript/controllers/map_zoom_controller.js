import { Controller } from "@hotwired/stimulus"
import Panzoom from "panzoom"

// Pan/zoom for the journey map, backed by the vendored, dependency-free
// @panzoom/panzoom (no CDN, CSP-clean).
export default class extends Controller {
  static targets = [ "content" ]
  static values = {
    initialScale: Number,
    centerX: Number,
    centerY: Number
  }

  connect() {
    this.pz = Panzoom(this.contentTarget, {
      maxScale: 5,
      minScale: 1,
      contain: "outside",
      cursor: "grab"
    })

    // @panzoom/panzoom does not bind wheel-zoom by default — wire it on the viewport.
    this.onWheel = this.pz.zoomWithWheel
    this.element.addEventListener("wheel", this.onWheel)

    if (this.hasInitialScaleValue && this.initialScaleValue > 1) {
      this.centerOnPoint(this.centerXValue || 50, this.centerYValue || 50, this.initialScaleValue)
    }
  }

  // Zoom to `scale` and pan so the (xPercent, yPercent) point of the content
  // sits at the centre of the viewport. Pan units are unscaled content pixels;
  // the element's default transform-origin is its centre.
  centerOnPoint(xPercent, yPercent, scale) {
    const contentWidth = this.contentTarget.offsetWidth
    const contentHeight = this.contentTarget.offsetHeight

    // Offset of the target point from the content's centre, in unscaled pixels.
    const offsetX = (xPercent / 100) * contentWidth - contentWidth / 2
    const offsetY = (yPercent / 100) * contentHeight - contentHeight / 2

    this.pz.zoom(scale, { animate: false })
    // Pan the opposite way to bring that point to the centre.
    this.pz.pan(-offsetX, -offsetY, { animate: false })
  }

  disconnect() {
    if (this.onWheel) this.element.removeEventListener("wheel", this.onWheel)
    if (this.pz) this.pz.destroy()
  }
}
