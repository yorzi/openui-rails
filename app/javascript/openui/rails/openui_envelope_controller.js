import { Controller } from "@hotwired/stimulus"

/**
 * Bridges a server transport into the surface controller.
 *
 * Turbo Streams cannot dispatch a custom event directly, so the Turbo
 * transport appends this element carrying a JSON envelope. On connect it
 * re-emits the envelope as `openui:envelope`, which bubbles to the surface
 * controller listening on `document`, then removes itself. No inline script
 * and no CSP relaxation are involved.
 *
 * The same event shape is what an Action Cable subscriber should dispatch.
 */
export default class extends Controller {
  connect() {
    const payload = this.element.dataset.openuiEnvelopePayload

    if (payload) {
      const detail = this.parse(payload)
      if (detail) {
        this.element.dispatchEvent(
          new CustomEvent("openui:envelope", { bubbles: true, detail })
        )
      }
    }

    this.element.remove()
  }

  parse(payload) {
    try {
      return JSON.parse(payload)
    } catch (error) {
      console.error("[openui-rails] invalid envelope payload", error)
      return null
    }
  }
}
