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
end
