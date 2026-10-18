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
    const connection = Symbol("openui-connection")
    this.connection = connection
    this.mountPoint = document.createElement("div")
    this.element.appendChild(this.mountPoint)
    this.abortController = new AbortController()
    this.state ||= {
      source: this.initialResponse,
      streaming: this.streaming,
      completed: false,
      nextSequence: Number(this.element.dataset.openuiNextSequence || 0),
      needsSnapshot: false,
    }

    this.onEnvelope = (event) => this.applyEnvelope(event.detail)
    // Listen on the document so any transport can deliver an envelope: a
    // dispatch on this element bubbles up, and the envelope controller (used by
    // the Turbo transport) re-emits from its own element. applyEnvelope ignores
    // envelopes for other message ids, so a shared document listener is safe.
    document.addEventListener("openui:envelope", this.onEnvelope)
    this.onBeforeCache = () => {
      this.element.dataset.openuiResponse = this.state.source
      this.element.dataset.openuiStreaming = String(this.state.streaming)
      this.element.dataset.openuiNextSequence = String(this.state.nextSequence)
      this.disconnect()
    }
    document.addEventListener("turbo:before-cache", this.onBeforeCache)

    this.syncBusy()
    this.renderRuntime(connection)
  }

  disconnect() {
    this.connection = null
    document.removeEventListener("openui:envelope", this.onEnvelope)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.abortController?.abort()
    this.root?.unmount()
    this.root = null
    this.mountPoint?.remove()
    this.mountPoint = null
  }

  async renderRuntime(connection) {
    try {
      const runtime = await loadRuntime(this.runtimeUrl, this.runtimeIntegrity)
      if (connection !== this.connection || !this.element.isConnected || !this.mountPoint) return
      this.runtime = runtime
      this.render()
    } catch (error) {
      if (connection !== this.connection) return
      this.state.streaming = false
      this.syncBusy()
      this.handleError(error)
    }
  }

  render() {
    this.syncBusy()
    if (!this.runtime || !this.mountPoint || !this.connection) return
    const { React, createRoot, Renderer, openuiChatLibrary } = this.runtime
    if (!this.root) this.root = createRoot(this.mountPoint)
    this.root.render(
      React.createElement(Renderer, {
        // The Renderer accepts either raw OpenUI Lang or a stored message that
        // carries `]]>openui:` markers, so one accumulated field is enough.
        response: this.state.source,
        library: openuiChatLibrary,
        isStreaming: this.state.streaming,
        initialState: this.initialState,
        // The official runtime emits { type, params }. It does not await this
        // void callback; dispatchAction already emits a structured error.
        onAction: (action) => { this.dispatchAction(action).catch(() => {}) },
        onStateUpdate: (formState) => this.persistState(formState),
        toolProvider: this.toolProvider(),
        onError: (error) => this.handleError(error),
      })
    )
  }

  // --- Streaming -----------------------------------------------------------

  applyEnvelope(envelope) {
    if (!envelope || envelope.message_id !== this.messageId) return
    if (!Number.isSafeInteger(envelope.sequence) || envelope.sequence < 0 ||
        (envelope.type === "openui.delta" && typeof envelope.delta !== "string") ||
        (envelope.type === "openui.snapshot" && typeof envelope.response !== "string")) {
      return this.handleError(Object.assign(new Error("Malformed stream envelope"), { code: "invalid_envelope" }))
    }
    if (envelope.library_version && this.libraryVersion && envelope.library_version !== this.libraryVersion) {
      return this.handleError(Object.assign(new Error("OpenUI library version mismatch"), { code: "library_version_mismatch" }))
    }
    if (envelope.type !== "openui.snapshot") {
      if (envelope.sequence < this.state.nextSequence || this.state.completed) return
      if (this.state.needsSnapshot || envelope.sequence > this.state.nextSequence) return this.requestSnapshot()
    }

    switch (envelope.type) {
      case "openui.delta":
        return this.applyDelta(envelope)
      case "openui.snapshot":
        return this.applySnapshot(envelope)
      case "openui.completed":
        this.state.nextSequence += 1
        this.state.streaming = false
        this.state.completed = true
        return this.render()
      case "openui.error":
        // A stream that ends in error is no longer busy, so assistive tech can
        // read whatever rendered before the failure.
        this.state.streaming = false
        this.state.completed = true
        this.state.nextSequence += 1
        this.syncBusy()
        return this.handleError(Object.assign(new Error(envelope.message || "stream error"), {
          code: envelope.code,
        }))
      default:
        return undefined
    }
  }

  applyDelta(envelope) {
    if (!this.withinByteLimit(this.state.source + envelope.delta)) return
    this.state.source = this.state.source + envelope.delta
    this.state.nextSequence += 1
    this.state.streaming = envelope.streaming !== false
    this.render()
  }

  applySnapshot(envelope) {
    const minimum = this.state.needsSnapshot ? this.state.nextSequence - 1 : this.state.nextSequence
    if (envelope.sequence < minimum || !this.withinByteLimit(envelope.response)) return
    this.state.source = envelope.response
    this.state.nextSequence = envelope.sequence + 1
    this.state.needsSnapshot = false
    this.state.streaming = envelope.streaming === true
    this.state.completed = !this.state.streaming
    this.render()
  }

  requestSnapshot() {
    if (this.state.needsSnapshot) return
    this.state.needsSnapshot = true
    this.dispatch("snapshot-required", { surfaceId: this.surfaceId, sequence: this.state.nextSequence })
  }

  withinByteLimit(source) {
    const limit = Number(this.element.dataset.openuiStreamByteLimit || 1048576)
    if (new TextEncoder().encode(source).byteLength <= limit) return true
    this.state.streaming = false
    this.state.completed = true
    this.syncBusy()
    this.handleError(Object.assign(new Error("OpenUI stream exceeds byte limit"), { code: "stream_too_large" }))
    return false
  }

  // --- Actions -------------------------------------------------------------

  async dispatchAction(payload = {}) {
    const body = {
      action: payload.action ?? payload.name ?? payload.type,
      args: payload.args ?? payload.params ?? {},
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
    const reserved = new Set([ "callTool", "then", "__proto__", "constructor", "prototype", "toJSON" ])
    return this.tools ||= new Proxy(
      {},
      {
        has: (_target, name) => typeof name === "string" && !reserved.has(name),
        get: (_target, name) => {
          if (typeof name !== "string" || reserved.has(name)) return undefined
          return (args) => this.dispatchAction({ action: name, args: args ?? {} }).then((result) => result.value)
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
  get libraryVersion() { return this.element.dataset.openuiLibraryVersion }
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
