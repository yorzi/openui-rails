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
      if (props.onAction) props.onAction({ action: "do.thing", args: { x: 1 } })
    })
    wrapper.appendChild(actionButton)

    const toolButton = document.createElement("button")
    toolButton.type = "button"
    toolButton.setAttribute("data-openui-tool", "Lookup")
    toolButton.textContent = "tool"
    toolButton.addEventListener("click", () => {
      if (props.toolProvider && props.toolProvider.Lookup) {
        props.toolProvider.Lookup({ q: "x" })
      }
    })
    wrapper.appendChild(toolButton)

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
