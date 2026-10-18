import { Controller } from "@hotwired/stimulus"

// The pinned runtime is fetched once per page and shared by every surface.
// A rejected promise is evicted so a later mount can retry.
const runtimePromises = new Map()

function loadRuntime(url, integrity) {
  if (!runtimePromises.has(url)) {
    const promise = new Promise((resolve, reject) => {
      const script = document.createElement("script")
      script.src = url
      script.async = true
      script.crossOrigin = "anonymous"
      if (integrity) script.integrity = integrity
      script.addEventListener("load", () => {
        if (!window.__OpenUI) {
          reject(new Error(`OpenUI runtime at ${url} did not expose window.__OpenUI`))
          return
        }
        resolve(window.__OpenUI)
      })
      script.addEventListener("error", () =>
        reject(new Error(`Failed to load the OpenUI runtime from ${url}`))
      )
      document.head.appendChild(script)
    })
    promise.catch(() => runtimePromises.delete(url))
    runtimePromises.set(url, promise)
  }
  return runtimePromises.get(url)
}

/**
 * Mounts the official OpenUI renderer against a server-owned surface.
 *
 * The element is a passive view: it renders the accumulated OpenUI Lang, routes
 * every action/tool call to the single Rails endpoint, and never holds a
 * credential. Streaming envelopes arrive as `openui:envelope` events and are
 * applied in order, ignoring duplicates and requesting a snapshot on a gap.
 */
export default class extends Controller {
  connect() {
    this.mountPoint = document.createElement("div")
    this.element.appendChild(this.mountPoint)
    this.abortController = new AbortController()
    this.state = {
      source: this.initialResponse,
      streaming: this.streaming,
      completed: false,
      nextSequence: 0,
      needsSnapshot: false,
    }

    this.onEnvelope = (event) => this.applyEnvelope(event.detail)
    // Listen on the document so any transport can deliver an envelope: a
    // dispatch on this element bubbles up, and the envelope controller (used by
    // the Turbo transport) re-emits from its own element. applyEnvelope ignores
    // envelopes for other message ids, so a shared document listener is safe.
    document.addEventListener("openui:envelope", this.onEnvelope)

    this.syncBusy()
    this.renderRuntime()
  }

  disconnect() {
    document.removeEventListener("openui:envelope", this.onEnvelope)
    this.abortController?.abort()
    this.root?.unmount()
    this.root = null
    this.mountPoint?.remove()
    this.mountPoint = null
  }

  async renderRuntime() {
    try {
      const runtime = await loadRuntime(this.runtimeUrl, this.runtimeIntegrity)
      if (!this.element.isConnected || !this.mountPoint) return
      this.runtime = runtime
      this.render()
    } catch (error) {
      this.handleError(error)
    }
  }

  render() {
    const { React, createRoot, Renderer, openuiChatLibrary } = this.runtime
    this.syncBusy()
    if (!this.root) this.root = createRoot(this.mountPoint)
    this.root.render(
      React.createElement(Renderer, {
        // The Renderer accepts either raw OpenUI Lang or a stored message that
        // carries `]]>openui:` markers, so one accumulated field is enough.
        response: this.state.source,
        library: openuiChatLibrary,
        isStreaming: this.state.streaming,
        initialState: this.initialState,
        onAction: (action) => this.dispatchAction(action),
        onStateUpdate: (formState) => this.persistState(formState),
        toolProvider: this.toolProvider(),
        onError: (error) => this.handleError(error),
      })
    )
  }

  // --- Streaming -----------------------------------------------------------

  applyEnvelope(envelope) {
    if (!envelope || envelope.message_id !== this.messageId) return

    switch (envelope.type) {
      case "openui.delta":
        return this.applyDelta(envelope)
      case "openui.snapshot":
        return this.applySnapshot(envelope)
      case "openui.completed":
        this.state.streaming = false
        this.state.completed = true
        return this.render()
      case "openui.error":
        // A stream that ends in error is no longer busy, so assistive tech can
        // read whatever rendered before the failure.
        this.state.streaming = false
        this.syncBusy()
        return this.handleError(Object.assign(new Error(envelope.message || "stream error"), {
          code: envelope.code,
        }))
      default:
        return undefined
    }
  }

  applyDelta(envelope) {
    if (envelope.sequence < this.state.nextSequence) return // duplicate: ignore

    if (envelope.sequence > this.state.nextSequence) {
      // Missing sequence: never execute a partial; ask for the canonical text.
      this.state.needsSnapshot = true
      this.dispatch("snapshot-required", {
        surfaceId: this.surfaceId,
        sequence: this.state.nextSequence,
      })
      return
    }

    this.state.source = this.state.source + envelope.delta
    this.state.nextSequence += 1
    this.state.streaming = envelope.streaming !== false
    this.render()
  }

  applySnapshot(envelope) {
    this.state.source = envelope.response
    this.state.nextSequence = envelope.sequence + 1
    this.state.needsSnapshot = false
    this.state.streaming = envelope.streaming === true
    this.render()
  }

  // --- Actions -------------------------------------------------------------

  async dispatchAction(payload = {}) {
    const body = {
      action: payload.action ?? payload.name,
      args: payload.args ?? {},
      surface_id: this.surfaceId,
      version: this.version,
      idempotency_key: payload.idempotency_key ?? this.newIdempotencyKey(),
      confirmed: payload.confirmed === true,
    }

    let response
    try {
      response = await fetch(this.actionsUrl, {
        method: "POST",
        credentials: "same-origin",
        signal: this.abortController.signal,
        headers: this.headers(),
        body: JSON.stringify(body),
      })
    } catch (error) {
      this.handleError(error)
      throw error
    }

    const json = await response.json().catch(() => ({}))
    if (!response.ok) {
      const error = Object.assign(new Error(json?.error?.message || "action failed"), {
        code: json?.error?.code,
      })
      this.handleError(error)
      throw error
    }

    this.dispatch("action", { surfaceId: this.surfaceId, result: json.result })
    return json.result
  }

  // Every browser `Query()`/`Mutation()` tool call is routed to the same
  // server endpoint; the host registry decides what is permitted.
  toolProvider() {
    return new Proxy(
      {},
      {
        has: () => true,
        get: (_target, name) => {
          if (typeof name !== "string") return undefined
          return (args) => this.dispatchAction({ action: name, args: args ?? {} })
        },
      }
    )
  }

  // Persisting form state is the host's job; emit an event and let it decide.
  persistState(formState) {
    this.dispatch("state", { surfaceId: this.surfaceId, state: formState })
  }

  // --- Helpers -------------------------------------------------------------

  // Mirror the streaming state onto `aria-busy` so a screen reader waits for a
  // streaming region to settle instead of announcing each delta.
  syncBusy() {
    this.element.setAttribute("aria-busy", this.state.streaming ? "true" : "false")
  }

  handleError(error) {
    console.error("[openui-rails]", error)
    this.dispatch("error", { surfaceId: this.surfaceId, message: error?.message, code: error?.code })
  }

  headers() {
    const token = document.querySelector("meta[name='csrf-token']")?.content
    const headers = { "Content-Type": "application/json", Accept: "application/json" }
    if (token) headers["X-CSRF-Token"] = token
    return headers
  }

  newIdempotencyKey() {
    if (window.crypto?.randomUUID) return window.crypto.randomUUID()
    return `${Date.now()}-${Math.random().toString(36).slice(2)}`
  }

  dispatch(name, detail) {
    this.element.dispatchEvent(new CustomEvent(`openui:${name}`, { bubbles: true, detail }))
  }

  get surfaceId() { return this.element.dataset.openuiSurfaceId }
  get messageId() { return this.element.dataset.openuiMessageId || this.surfaceId }
  get version() { return Number(this.element.dataset.openuiVersion || 0) }
  get streaming() { return this.element.dataset.openuiStreaming === "true" }
  get actionsUrl() { return this.element.dataset.openuiActionsUrl }
  get runtimeUrl() { return this.element.dataset.openuiRuntimeUrl }
  get runtimeIntegrity() { return this.element.dataset.openuiRuntimeIntegrity }

  get initialResponse() { return this.element.dataset.openuiResponse || "" }

  get initialState() {
    const raw = this.element.dataset.openuiInitialState
    if (!raw) return undefined
    try {
      return JSON.parse(raw)
    } catch {
      return undefined
    }
  }
}
