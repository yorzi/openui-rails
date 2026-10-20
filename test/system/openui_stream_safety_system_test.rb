# frozen_string_literal: true

require "application_system_test_case"

class OpenUIStreamSafetySystemTest < ApplicationSystemTestCase
  setup do
    visit "/demo"
    within_surface("surface-2") { assert_selector "[data-openui-rendered]" }
    install_recorders
  end

  test "a completion with missing deltas requests a snapshot" do
    dispatch(delta("surface-2", 0, "A"))
    dispatch({ "message_id" => "surface-2", "sequence" => 2, "type" => "openui.completed" })

    assert_selector "body[data-openui-last-snapshot]"
    assert_selector "[data-openui-surface-id='surface-2'][aria-busy='true']"
  end

  test "stale snapshots cannot overwrite a newer source" do
    dispatch(delta("surface-2", 0, "A"))
    dispatch(delta("surface-2", 1, "B"))
    before = source_of("surface-2")
    dispatch({ "message_id" => "surface-2", "sequence" => 0, "type" => "openui.snapshot", "response" => "stale" })

    assert_equal before, source_of("surface-2")
  end

  test "mismatched libraries and malformed frames are rejected without changing source" do
    before = source_of("surface-2")
    dispatch(delta("surface-2", 0, "wrong").merge("library_version" => "sha256:other"))

    assert_selector "body[data-openui-last-error]"
    assert_equal "library_version_mismatch", read_json("body", "data-openui-last-error")["code"]
    assert_equal before, source_of("surface-2")
    dispatch(delta("surface-2", "0", "malformed"))
    assert_equal before, source_of("surface-2")
  end

  test "disconnect and reconnect preserve the source and duplicate watermark" do
    dispatch(delta("surface-2", 0, "A"))
    before = source_of("surface-2")
    page.execute_script(<<~JS)
      window.detachedSurface = document.querySelector("[data-openui-surface-id='surface-2']")
      window.detachedSurface.remove()
    JS
    assert eventually { page.evaluate_script("window.__openuiMounts.some((mount) => mount.unmounted)") }
    page.execute_script("document.body.appendChild(window.detachedSurface)")
    within_surface("surface-2") { assert_selector "[data-openui-rendered]" }
    assert_equal before, source_of("surface-2")
    dispatch(delta("surface-2", 0, "A"))

    assert_equal before, source_of("surface-2")
  end

  test "events arriving before the runtime is available are retained for the first render" do
    error = page.evaluate_script(<<~JS)
      (() => {
        const element = document.querySelector("[data-openui-surface-id='surface-2']")
        const controller = window.Stimulus.getControllerForElementAndIdentifier(element, "openui")
        const runtime = controller.runtime
        controller.runtime = null
        let failure = null
        try {
          controller.applyEnvelope({ type: "openui.delta", message_id: "surface-2", sequence: 0, delta: "early" })
        } catch (error) { failure = error.message }
        controller.runtime = runtime
        controller.render()
        return failure
      })()
    JS

    assert_nil error
    within_surface("surface-2") { assert_selector "[data-openui-source]", text: /early\z/ }
  end

  test "oversized source is rejected before passing it to the renderer" do
    before = source_of("surface-2")
    page.execute_script("document.querySelector('[data-openui-surface-id=surface-2]').dataset.openuiStreamByteLimit = '64'")
    dispatch(delta("surface-2", 0, "x" * 65))

    assert_selector "body[data-openui-last-error]"
    assert_equal "stream_too_large", read_json("body", "data-openui-last-error")["code"]
    assert_equal before, source_of("surface-2")
  end

  test "Turbo cache snapshots contain source and sequence state but no mounted React tree" do
    dispatch(delta("surface-2", 0, "A"))
    before = source_of("surface-2")
    page.execute_script("document.dispatchEvent(new Event('turbo:before-cache'))")

    assert_no_selector "[data-openui-rendered]", visible: :all
    assert_equal before, find("[data-openui-surface-id='surface-2']", visible: :all)["data-openui-response"]
    assert_equal "1", find("[data-openui-surface-id='surface-2']", visible: :all)["data-openui-next-sequence"]
  end

  test "a missing runtime reports an error and clears the busy state" do
    page.execute_script(<<~JS)
      const clone = document.querySelector("[data-openui-surface-id='surface-2']").cloneNode(false)
      clone.id = "missing-runtime"
      clone.dataset.openuiSurfaceId = "missing-runtime"
      clone.dataset.openuiRuntimeUrl = "/missing-openui-runtime.js"
      delete clone.dataset.openuiRuntimeIntegrity
      document.body.appendChild(clone)
    JS

    assert_selector "body[data-openui-last-error]"
    assert_selector "#missing-runtime[aria-busy='false']", visible: :all
    assert_equal "runtime_load_failed", read_json("body", "data-openui-last-error")["code"]
    assert_no_selector "#missing-runtime [data-openui-rendered]", visible: :all
  end

  test "a runtime library that differs from the configured spec never mounts" do
    page.execute_script(<<~JS)
      window.__OpenUI.openuiChatLibrary.toSpec = () => ({ components: [] })
      const clone = document.querySelector("[data-openui-surface-id='surface-2']").cloneNode(false)
      clone.id = "wrong-library"
      clone.dataset.openuiSurfaceId = "wrong-library"
      document.body.appendChild(clone)
    JS

    assert_selector "body[data-openui-last-error]"
    assert_equal "library_version_mismatch", read_json("body", "data-openui-last-error")["code"]
    assert_no_selector "#wrong-library [data-openui-rendered]", visible: :all
  end

  test "only an accepted snapshot emits its applied sequence" do
    page.execute_script(<<~JS)
      window.appliedSnapshots = []
      document.addEventListener("openui:snapshot-applied", event => window.appliedSnapshots.push(event.detail))
    JS
    dispatch(delta("surface-2", 0, "A"))
    dispatch(delta("surface-2", 2, "gap"))
    dispatch({ "message_id" => "surface-2", "sequence" => 1, "type" => "openui.snapshot", "response" => "restored" })
    within_surface("surface-2") { assert_selector "[data-openui-source]", text: "restored" }
    assert_equal [ { "surfaceId" => "surface-2", "sequence" => 1 } ], page.evaluate_script("window.appliedSnapshots")
    dispatch({ "message_id" => "surface-2", "sequence" => 0, "type" => "openui.snapshot", "response" => "stale" })
    assert_equal 1, page.evaluate_script("window.appliedSnapshots.length")
  end

  test "callbacks retained by an unmounted renderer cannot use a new connection" do
    page.execute_script(<<~JS)
      const element = document.querySelector('[data-openui-surface-id=surface-2]')
      window.oldProps = window.__openuiMounts.findLast(mount => mount.container.parentElement === element).props
      window.detachedCallbackSurface = element
      element.remove()
    JS
    assert eventually { page.evaluate_script("window.__openuiMounts.some(mount => mount.unmounted)") }
    page.execute_script("document.body.appendChild(window.detachedCallbackSurface)")
    within_surface("surface-2") { assert_selector "[data-openui-rendered]" }
    observed = page.driver.browser.execute_async_script(<<~JS)
      const done = arguments[arguments.length - 1]
      let requests = 0, states = 0
      window.fetch = async () => { requests++; return new Response('{}', {headers: {'Content-Type': 'application/json'}}) }
      document.addEventListener('openui:state', () => states++)
      window.oldProps.onError(new Error('old renderer failed'))
      window.oldProps.onStateUpdate({private: 'old state'})
      window.oldProps.onAction({action: 'orders.refresh', args: {orderId: 42}})
      window.oldProps.toolProvider['orders.refresh']({orderId: 42}).catch(() => {}).then(() => done({requests, states}))
    JS
    assert_equal({ "requests" => 0, "states" => 0 }, observed)
    assert_no_selector "body[data-openui-last-error]"
    assert_no_selector "body[data-openui-last-action]"
  end
end
