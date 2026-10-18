// Test stub for the pinned OpenUI browser runtime.
//
// The real @openuidev/browser-bundle is fetched with `bin/rails
// openui:runtime:fetch` and is not committed. The browser tests exercise the
// openui-rails Stimulus controller and the real, version-pinned runtime is not
// what is under test, so this file provides just enough of `window.__OpenUI`
// (React.createElement, createRoot, Renderer, openuiChatLibrary) to drive the
// controller deterministically and offline.
//
// It renders a data-* mirror of the props it received and two buttons that call
// the onAction / toolProvider seams, so a system test can assert on both the
// rendered source and the action round-trip.
(function () {
  const mounts = []
  window.__openuiMounts = mounts

  const React = {
    createElement(type, props) {
      return { type, props: props || {} }
    },
  }

  function renderToDom(container, props) {
    props = props || {}
    container.innerHTML = ""

    const wrapper = document.createElement("div")
    wrapper.setAttribute("data-openui-rendered", "true")
    wrapper.setAttribute("data-openui-streaming", String(props.isStreaming === true))
    wrapper.setAttribute("data-openui-library", String((props.library || {}).id || ""))

    const source = document.createElement("span")
    source.setAttribute("data-openui-source", "true")
    source.textContent = props.response || ""
    wrapper.appendChild(source)

    const actionButton = document.createElement("button")
    actionButton.type = "button"
    actionButton.setAttribute("data-openui-action", "do.thing")
    actionButton.textContent = "action"
    actionButton.addEventListener("click", () => {
      if (props.onAction) props.onAction({ type: "do.thing", params: { x: 1 }, humanFriendlyMessage: "Run action" })
    })
    wrapper.appendChild(actionButton)

    const toolButton = document.createElement("button")
    toolButton.type = "button"
    toolButton.setAttribute("data-openui-tool", "Lookup")
    toolButton.textContent = "tool"
    toolButton.addEventListener("click", () => {
      if (props.toolProvider && props.toolProvider.Lookup) {
        // Match the real Renderer's MCP-vs-function-map detection.
        const provider = props.toolProvider
        const request = typeof provider.callTool === "function"
          ? provider.callTool({ name: "Lookup", arguments: { q: "x" } })
          : provider.Lookup({ q: "x" })
        request.then((result) => { document.body.dataset.openuiToolValue = JSON.stringify(result) })
      }
    })
    wrapper.appendChild(toolButton)

    // A destructive action submitted without confirmation, and the same action
    // submitted after the host collected confirmation.
    const unconfirmedButton = document.createElement("button")
    unconfirmedButton.type = "button"
    unconfirmedButton.setAttribute("data-openui-action-unconfirmed", "do.destructive")
    unconfirmedButton.textContent = "delete (unconfirmed)"
    unconfirmedButton.addEventListener("click", () => {
      if (props.onAction) props.onAction({ action: "do.destructive", args: {} })
    })
    wrapper.appendChild(unconfirmedButton)

    const confirmedButton = document.createElement("button")
    confirmedButton.type = "button"
    confirmedButton.setAttribute("data-openui-action-confirmed", "do.destructive")
    confirmedButton.textContent = "delete (confirmed)"
    confirmedButton.addEventListener("click", () => {
      if (props.onAction) props.onAction({ action: "do.destructive", args: {}, confirmed: true })
    })
    wrapper.appendChild(confirmedButton)

    container.appendChild(wrapper)
  }

  function createRoot(container) {
    const record = { container, renders: 0, unmounted: false, props: null }
    mounts.push(record)

    return {
      render(element) {
        record.renders += 1
        record.props = element && element.props
        renderToDom(container, record.props)
      },
      unmount() {
        record.unmounted = true
        container.innerHTML = ""
      },
    }
  }

  window.__OpenUI = {
    React,
    createRoot,
    Renderer: "Renderer",
    openuiChatLibrary: { id: "stub-chat-library" },
  }
})()
