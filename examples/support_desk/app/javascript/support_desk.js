import { Application, Controller } from "@hotwired/stimulus"
import "@hotwired/turbo-rails"
import OpenUIController from "openui/rails/openui_controller"
import EnvelopeController from "openui/rails/openui_envelope_controller"

class SupportDeskController extends Controller {
  connect() {
    this.connection = Symbol("support-desk")
    this.abort = new AbortController()
    this.saves = Promise.resolve()
    this.lastState = null
    this.runtimeReady = false
    this.recovering = false
    this.failureCode = this.element.dataset.supportDeskFailure || null
    this.beforeCache = () => this.disconnect()
    document.addEventListener("turbo:before-cache", this.beforeCache)
    if (this.surface.dataset.openuiStreaming === "true" && !this.failureCode) {
      const connection = this.connection
      this.stream(connection).catch(error => { if (this.current(connection)) this.failure(error) })
    }
  }

  disconnect() {
    this.connection = null
    this.abort?.abort()
    document.removeEventListener("turbo:before-cache", this.beforeCache)
  }
  current(connection) { return !!connection && connection === this.connection && this.element.isConnected }
  get surface() { return this.element.querySelector("[data-controller='openui']") }
  get status() { return this.element.querySelector("#desk-status") }
  get fallback() { return this.element.querySelector("#desk-fallback") }
  get recoverButton() { return this.element.querySelector("#desk-recover") }

  headers() {
    return { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']").content }
  }

  checked(response) {
    if (response.redirected || [401, 403].includes(response.status)) {
      throw Object.assign(new Error("Session or permission rejected"), { code: "unauthorized" })
    }
    if (!response.ok) throw Object.assign(new Error("Request rejected"), {
      code: response.status === 409 ? "stale_surface" : "request_failed"
    })
    return response
  }

  ready() {
    this.runtimeReady = true
    if (!this.failureCode) {
      this.fallback.hidden = true
      this.surface.inert = false
    }
  }

  // Persisted canonical output is independent of this disposable connection.
  async stream(connection) {
    const response = await fetch(this.element.dataset.supportDeskStreamUrl, {
      method: "POST", headers: this.headers(), signal: this.abort.signal, credentials: "same-origin"
    })
    if (!this.current(connection)) return
    this.checked(response)
    const reader = response.body.getReader()
    const decoder = new TextDecoder()
    let pending = ""
    try {
      while (true) {
        const { value, done } = await reader.read()
        if (!this.current(connection)) return
        pending += decoder.decode(value, { stream: !done })
        let end
        while ((end = pending.indexOf("\n")) >= 0) {
          window.Turbo.renderStreamMessage(pending.slice(0, end))
          pending = pending.slice(end + 1)
        }
        if (done) break
      }
      if (pending.trim()) throw new Error("Incomplete stream")
      if (!this.failureCode) this.status.textContent = "Response loaded"
    } finally {
      await reader.cancel().catch(() => {})
    }
  }

  async recover() {
    if (!this.current(this.connection) || this.recovering || ["unauthorized", "csrf_failed"].includes(this.failureCode)) return
    const connection = this.connection
    this.recovering = true
    this.failure({ code: "sequence_gap" })
    this.recoverButton.disabled = true
    this.recoverButton.setAttribute("aria-busy", "true")
    this.status.textContent = "Restoring saved response"
    try {
      const response = await fetch(this.element.dataset.supportDeskSnapshotUrl, {
        headers: { Accept: "application/json" }, signal: this.abort.signal, credentials: "same-origin"
      })
      if (!this.current(connection)) return
      const envelope = await this.checked(response).json()
      if (!this.current(connection)) return
      this.snapshotApplied = false
      this.surface.dispatchEvent(new CustomEvent("openui:envelope", { bubbles: true, detail: envelope }))
      if (!this.snapshotApplied) throw Object.assign(new Error("Snapshot not accepted"), { code: "snapshot_unavailable" })
    } catch (error) {
      if (this.current(connection)) this.failure(error)
    } finally {
      if (this.current(connection)) {
        this.recovering = false
        this.recoverButton.disabled = this.failureCode !== "sequence_gap" && this.failureCode !== "request_failed"
        this.recoverButton.setAttribute("aria-busy", "false")
      }
    }
  }

  restored() {
    this.snapshotApplied = true
    // A transport snapshot cannot restore identity or permission. Keep that
    // failure visible until the host performs a fresh sign-in or reload.
    if (this.failureCode && !["sequence_gap", "request_failed"].includes(this.failureCode)) return
    this.failureCode = null
    delete this.element.dataset.supportDeskFailure
    this.element.dataset.recovered = "true"
    this.element.querySelector("#desk-error").textContent = ""
    this.status.textContent = "Recovered from a missing update"
    this.surface.inert = false
    if (this.runtimeReady) this.fallback.hidden = true
  }

  saveState(event) {
    const note = event.detail.state?.reply?.note
    if (!note || typeof note.value !== "string") return
    const state = { reply: { note: { value: note.value, componentType: "Input" } } }
    const serialized = JSON.stringify(state)
    if (this.lastState === serialized) return
    this.lastState = serialized
    this.status.textContent = "Saving draft"
    const connection = this.connection, signal = this.abort.signal
    const version = Number(this.surface.dataset.openuiVersion)
    this.saves = this.saves.then(async () => {
      if (!this.current(connection)) return
      const response = await fetch(this.element.dataset.supportDeskStateUrl, {
        method: "PATCH", headers: this.headers(), credentials: "same-origin", signal,
        body: JSON.stringify({ state, version })
      })
      if (!this.current(connection)) return
      this.checked(response)
      if (this.lastState === serialized && !this.failureCode) this.status.textContent = "Draft saved"
    }).catch(error => { if (this.current(connection)) this.failure(error) })
  }

  async action(event) {
    if (!["continue_conversation", "close_ticket"].includes(event.detail.result.action)) return
    const connection = this.connection
    await this.saves
    if (this.current(connection)) window.location.reload()
  }

  error(event) {
    // The runtime can report a secondary parse failure after an action error.
    // Keep the actionable server outcome instead of replacing it with that echo.
    if (this.failureCode && event.detail.code === "renderer_error") return
    this.failure(event.detail)
  }

  failure(error) {
    if (error.name === "AbortError") return
    this.failureCode = error.code || "request_failed"
    this.element.dataset.supportDeskFailure = this.failureCode
    const messages = {
      runtime_load_failed: "Interactive view could not load. Review the ticket details or reload.",
      library_version_mismatch: "The response uses a different library. Reload after correcting setup.",
      provider_rejected: "Generation stopped. Reload the saved conversation before trying again.",
      stream_failed: "Generation stopped. Reload the saved conversation before trying again.",
      stream_cancelled: "Generation stopped. Reload the saved conversation before trying again.",
      stream_too_large: "The response is too large. Reload the saved conversation.",
      stale_surface: "Conversation changed. Reload before submitting another action.",
      unauthorized: "Action not permitted. Sign in again.",
      csrf_failed: "Action not permitted. Sign in again.",
      sequence_gap: "An update is missing. Restore the saved response or reload.",
      snapshot_unavailable: "Saved response cannot be applied. Reload the conversation.",
      renderer_error: "Interactive response could not render. Reload the conversation."
    }
    this.element.querySelector("#desk-error").textContent = messages[this.failureCode] || "Request failed; its outcome may be unknown. Reload canonical state before trying again."
    this.fallback.hidden = false
    this.surface.inert = true
    this.recoverButton.disabled = !["sequence_gap", "request_failed"].includes(this.failureCode)
    this.element.querySelector("#desk-sign-in").hidden = !["unauthorized", "csrf_failed"].includes(this.failureCode)
    this.status.textContent = "Recovery required"
  }
}

const application = Application.start()
application.register("support-desk", SupportDeskController)
application.register("openui", OpenUIController)
application.register("openui-envelope", EnvelopeController)
