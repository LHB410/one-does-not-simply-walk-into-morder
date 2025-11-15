import { Controller } from "@hotwired/stimulus"
import panzoom from "panzoom"

export default class extends Controller {
  static targets = [ "content" ]
  static values = {
    initialScale: Number,
    centerX: Number,
    centerY: Number
  }

  connect() {
    this.pz = panzoom(this.contentTarget, {
      bounds: true,
      smoothScroll: false,
      maxZoom: 5,
      minZoom: 1,
      autocenter: false
    })

    if (this.hasInitialScaleValue && this.initialScaleValue > 1) {
      this.pz.zoomAbs(0, 0, this.initialScaleValue)
      this.centerOnPoint(this.centerXValue || 50, this.centerYValue || 50)
    }
  }

  centerOnPoint(xPercent, yPercent) {
    // Use untransformed content dimensions to avoid double-scaling
    const contentWidth = this.contentTarget.offsetWidth
    const contentHeight = this.contentTarget.offsetHeight
    const { scale } = this.pz.getTransform()

    const pointXContent = (xPercent / 100) * contentWidth
    const pointYContent = (yPercent / 100) * contentHeight

    // Target is the center of the viewport hosting the panzoom element
    const viewport = this.element.getBoundingClientRect()
    const targetX = viewport.width / 2
    const targetY = viewport.height / 2

    // Compute absolute translation to place the scaled content point at viewport center
    const translateX = targetX - (pointXContent * scale)
    const translateY = targetY - (pointYContent * scale)

    this.pz.moveTo(translateX, translateY)
  }

  disconnect() {
    if (this.pz) this.pz.dispose()
  }
}


