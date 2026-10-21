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
      const failed = (message) => {
        script.remove()
        reject(Object.assign(new Error(message), { code: "runtime_load_failed" }))
      }
      script.addEventListener("load", () => {
        if (!window.__OpenUI) {
          failed("OpenUI runtime did not expose window.__OpenUI")
          return
        }
        resolve(window.__OpenUI)
      })
      script.addEventListener("error", () => failed("Failed to load the OpenUI runtime"))
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
      completed: this.element.dataset.openuiCompleted === "true",
      nextSequence: Number(this.element.dataset.openuiNextSequence || 0),
      needsSnapshot: this.element.dataset.openuiNeedsSnapshot === "true",
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
      this.element.dataset.openuiCompleted = String(this.state.completed)
      this.element.dataset.openuiNeedsSnapshot = String(this.state.needsSnapshot)
      this.disconnect()
    }
    document.addEventListener("turbo:before-cache", this.onBeforeCache)

    this.syncBusy()
    this.renderRuntime(connection)
    // A surface restored from the Turbo cache or reattached while paused for a
    // snapshot would otherwise wait forever: the host abandoned the earlier
    // request on disconnect. Announce it again once sibling controllers connect.
    if (this.state.needsSnapshot) {
      queueMicrotask(() => { if (this.isCurrent(connection)) this.announceSnapshotRequired() })
    }
  }

  disconnect() {
    this.connection = null
    document.removeEventListener("openui:envelope", this.onEnvelope)
    document.removeEventListener("turbo:before-cache", this.onBeforeCache)
    this.abortController?.abort()
    this.root?.unmount()
    this.root = null
    this.runtime = null
    this.tools = null
    this.mountPoint?.remove()
    this.mountPoint = null
  }

  async renderRuntime(connection) {
    try {
      const runtime = await loadRuntime(this.runtimeUrl, this.runtimeIntegrity)
      await this.verifyLibrary(runtime.openuiChatLibrary)
      if (!this.isCurrent(connection) || !this.mountPoint) return
      this.runtime = runtime
      if (this.render()) this.dispatch("ready", { surfaceId: this.surfaceId })
    } catch (error) {
      if (!this.isCurrent(connection)) return
      this.state.streaming = false
      this.syncBusy()
      this.handleError(error)
    }
  }

  render() {
    this.syncBusy()
    if (!this.runtime || !this.mountPoint || !this.connection) return
    if (!this.withinByteLimit(this.state.source)) return
    const { React, createRoot, Renderer, openuiChatLibrary } = this.runtime
    const connection = this.connection
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
        onAction: (action) => { if (this.isCurrent(connection)) this.dispatchAction(action).catch(() => {}) },
        onStateUpdate: (formState) => { if (this.isCurrent(connection)) this.persistState(formState) },
        toolProvider: this.toolProvider(),
        onError: (error) => { if (this.isCurrent(connection)) this.handleError(error) },
      })
    )
    return true
  }

  async verifyLibrary(library) {
    const expected = this.element.dataset.openuiLibraryFingerprint
    if (!expected) return
    if (typeof library?.toSpec !== "function" || !window.crypto?.subtle) {
      throw Object.assign(new Error("Cannot verify the configured OpenUI library"), { code: "library_version_mismatch" })
    }
    const canonical = (value) => {
      if (Array.isArray(value)) return value.map(canonical)
      if (value !== null && typeof value === "object") {
        return Object.fromEntries(Object.keys(value).sort().map((key) => [ key, canonical(value[key]) ]))
      }
      return value
    }
    const bytes = new TextEncoder().encode(JSON.stringify(canonical(library.toSpec())))
    const digest = await window.crypto.subtle.digest("SHA-256", bytes)
    const fingerprint = `sha256:${Array.from(new Uint8Array(digest), (byte) => byte.toString(16).padStart(2, "0")).join("")}`
    if (fingerprint !== expected) {
      throw Object.assign(new Error("Runtime library differs from the configured prompt/spec library"), { code: "library_version_mismatch" })
    }
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
    this.dispatch("snapshot-applied", { surfaceId: this.surfaceId, sequence: envelope.sequence })
  }

  requestSnapshot() {
    if (this.state.needsSnapshot) return
    this.state.needsSnapshot = true
    this.announceSnapshotRequired()
  }

  announceSnapshotRequired() {
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
    const connection = this.connection
    if (!this.isCurrent(connection)) throw new DOMException("Surface disconnected", "AbortError")
    const body = {
      action: payload.action ?? payload.name ?? payload.type,
      args: this.actionArguments(payload),
      surface_id: this.surfaceId,
      version: this.version,
      idempotency_key: payload.idempotency_key ?? this.newIdempotencyKey(),
      confirmed: payload.confirmed === true,
    }

    try {
      const response = await fetch(this.actionsUrl, {
        method: "POST",
        credentials: "same-origin",
        signal: this.abortController.signal,
        headers: this.headers(),
        body: JSON.stringify(body),
      })
      if (!this.isCurrent(connection)) throw new DOMException("Surface disconnected", "AbortError")
      if (response.redirected) {
        throw Object.assign(new Error("Action request was redirected; authentication may have expired"), { code: "unauthorized" })
      }
      if (!response.headers.get("Content-Type")?.includes("application/json")) {
        throw Object.assign(new Error("Action endpoint did not return JSON"), { code: "invalid_response" })
      }
      let json
      try {
        json = await response.json()
      } catch {
        throw Object.assign(new Error("Action endpoint returned malformed JSON"), { code: "invalid_response" })
      }
      if (!this.isCurrent(connection)) throw new DOMException("Surface disconnected", "AbortError")
      if (!response.ok) {
        throw Object.assign(new Error(json?.error?.message || "action failed"), { code: json?.error?.code || "action_failed" })
      }
      const result = json?.result
      if (!result || result.action !== body.action || result.surface_id !== body.surface_id || result.version !== body.version) {
        throw Object.assign(new Error("Action response does not match the submitted action"), { code: "invalid_response" })
      }
      this.dispatch("action", { surfaceId: this.surfaceId, result })
      return result
    } catch (error) {
      if (this.isCurrent(connection)) this.handleError(error, error.name === "AbortError" ? "request_cancelled" : "network_error")
      throw error
    }
  }

  // The official renderer places conversation metadata beside params. Keep
  // it in the allowlisted action's args so the host can validate and persist it.
  actionArguments(payload) {
    const args = payload.args ?? payload.params ?? {}
    if ((payload.action ?? payload.name ?? payload.type) !== "continue_conversation") return args
    if (typeof args !== "object" || Array.isArray(args)) return args
    const metadata = {}
    if (payload.humanFriendlyMessage !== undefined) metadata.message = payload.humanFriendlyMessage
    if (payload.formState !== undefined) metadata.form_state = payload.formState
    if (payload.formName !== undefined) metadata.form_name = payload.formName
    return { ...args, ...metadata }
  }

  // Every browser `Query()`/`Mutation()` tool call is routed to the same
  // server endpoint; the host registry decides what is permitted.
  toolProvider() {
    const connection = this.connection
    const reserved = new Set([ "callTool", "then", "__proto__", "constructor", "prototype", "toJSON" ])
    return this.tools ||= new Proxy(
      {},
      {
        has: (_target, name) => typeof name === "string" && !reserved.has(name),
        get: (_target, name) => {
          if (typeof name !== "string" || reserved.has(name)) return undefined
          return (args) => {
            if (!this.isCurrent(connection)) return Promise.reject(new DOMException("Surface disconnected", "AbortError"))
            return this.dispatchAction({ action: name, args: args ?? {} }).then((result) => result.value)
          }
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

  handleError(error, fallbackCode = "renderer_error") {
    // Renderer#onError receives an array, including [] after successful parses.
    if (Array.isArray(error)) {
      if (error.length === 0) return
      error = Object.assign(new Error(error.map((entry) => entry.message || String(entry)).join("; ")),
        { code: "renderer_error" })
    }
    this.dispatch("error", { surfaceId: this.surfaceId, message: error?.message,
      code: typeof error?.code === "string" ? error.code : fallbackCode })
  }

  isCurrent(connection) { return !!connection && connection === this.connection && this.element.isConnected }

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
