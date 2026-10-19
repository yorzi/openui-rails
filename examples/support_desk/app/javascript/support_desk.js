import { Application, Controller } from "@hotwired/stimulus"
import "@hotwired/turbo-rails"
import OpenUIController from "openui/rails/openui_controller"
import EnvelopeController from "openui/rails/openui_envelope_controller"

class SupportDeskController extends Controller {
  connect() {
    this.abort = new AbortController()
    this.saves = Promise.resolve()
    this.lastState = null
    if (this.surface.dataset.openuiStreaming === "true") this.stream().catch(error => this.failure(error))
  }

  disconnect() { this.abort.abort() }
  get surface() { return this.element.querySelector("[data-controller='openui']") }
  get status() { return this.element.querySelector("#desk-status") }

  headers() {
    return { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content }
  }

  async checked(response) {
    if (response.redirected || !response.ok) throw new Error(response.status === 401 || response.status === 403 ? "Session expired. Sign in again." : "Request rejected. Reload the conversation.")
    return response
  }

  // Consume newline-delimited Turbo Stream elements as response chunks arrive.
  // Authorization and canonical response persistence happen before delivery.
  async stream() {
    const response = await this.checked(await fetch(this.element.dataset.supportDeskStreamUrl, {
      method: "POST", headers: this.headers(), signal: this.abort.signal, credentials: "same-origin"
    }))
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let pending = ""
    try {
      while (true) {
        const { value, done } = await reader.read()
        pending += decoder.decode(value, { stream: !done })
        let end
        while ((end = pending.indexOf("\n")) >= 0) {
          window.Turbo.renderStreamMessage(pending.slice(0, end))
          pending = pending.slice(end + 1)
        }
        if (done) break
      }
      if (pending.trim()) throw new Error("Incomplete stream. Reload the conversation.")
      this.status.textContent = "Response loaded"
    } finally {
      await reader.cancel().catch(() => {})
    }
  }

  async recover() {
    if (this.recovering) return
    this.recovering = true
    try {
      const response = await this.checked(await fetch(this.element.dataset.supportDeskSnapshotUrl, {
        headers: { Accept: "application/json" }, signal: this.abort.signal, credentials: "same-origin"
      }))
      const envelope = await response.json()
      this.surface.dispatchEvent(new CustomEvent("openui:envelope", { bubbles: true, detail: envelope }))
      this.element.dataset.recovered = "true"
      this.status.textContent = "Recovered from a missing update"
    } catch (error) { this.failure(error) }
    finally { this.recovering = false }
  }

  saveState(event) {
    const note = event.detail.state?.reply?.note
    if (!note || typeof note.value !== "string") return
    const state = { reply: { note: { value: note.value, componentType: "Input" } } }
    const serialized = JSON.stringify(state)
    if (this.lastState === serialized) return
    this.lastState = serialized
    this.status.textContent = "Saving draft"
    const version = Number(this.surface.dataset.openuiVersion)
    this.saves = this.saves.then(async () => {
      await this.checked(await fetch(this.element.dataset.supportDeskStateUrl, {
        method: "PATCH", headers: this.headers(), credentials: "same-origin", signal: this.abort.signal,
        body: JSON.stringify({ state, version })
      }))
      if (this.lastState === serialized) this.status.textContent = "Draft saved"
    }).catch(error => this.failure(error))
  }

  async action(event) {
    if (!["continue_conversation", "close_ticket"].includes(event.detail.result.action)) return
    await this.saves
    window.location.reload()
  }

  error(event) {
    if (["unauthorized", "csrf_failed"].includes(event.detail.code)) {
      this.denied = true
      this.failure(new Error("Action not permitted. Sign in again."))
    } else if (!this.denied) {
      this.failure(new Error(event.detail.message || "Unable to render this response."))
    }
  }
  failure(error) {
    if (error.name !== "AbortError") this.element.querySelector("#desk-error").textContent = error.message
  }
}

const application = Application.start()
application.register("support-desk", SupportDeskController)
application.register("openui", OpenUIController)
application.register("openui-envelope", EnvelopeController)
