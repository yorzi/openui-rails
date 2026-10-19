# frozen_string_literal: true

require "application_system_test_case"

# Browser end-to-end coverage for the openui-rails Stimulus controller driven
# against the deterministic stub runtime in test/dummy/public/openui. These
# cover the lifecycle, streaming-order and action behaviors that unit tests
# cannot reach.
class OpenUISurfacesSystemTest < ApplicationSystemTestCase
  setup do
    visit "/demo"
    install_recorders
  end

  test "mounts one React root per surface without leaking" do
    assert_selector ".openui-surface[data-openui-surface-id='surface-1']"
    assert_selector ".openui-surface[data-openui-surface-id='surface-2']"

    assert_equal 2, page.evaluate_script("window.__openuiMounts.length")
    assert_equal [ false, false ], page.evaluate_script("window.__openuiMounts.map((m) => m.unmounted)")
  end

  test "streaming deltas accumulate in sequence order" do
    dispatch(delta("surface-2", 0, "X"))
    dispatch(delta("surface-2", 1, "Y"))

    within_surface("surface-2") do
      assert_selector "[data-openui-source]", text: %q{root = TextContent("Streaming")XY}
    end
  end

  test "a duplicated delta is ignored" do
    dispatch(delta("surface-2", 0, "A"))
    within_surface("surface-2") { assert_selector "[data-openui-source]", text: /A\z/ }

    dispatch(delta("surface-2", 0, "A"))

    within_surface("surface-2") do
      assert_selector "[data-openui-source]", text: /A\z/
      refute_selector "[data-openui-source]", text: "AA"
    end
  end

  test "a sequence gap requests a snapshot instead of a partial render" do
    before = source_of("surface-2")

    dispatch(delta("surface-2", 3, "gap"))

    assert_selector "body[data-openui-last-snapshot]"
    snapshot = read_json("body", "data-openui-last-snapshot")
    assert_equal 0, snapshot["sequence"]
    assert_equal "surface-2", snapshot["surfaceId"]
    assert_equal before, source_of("surface-2")
  end

  test "a snapshot replaces the accumulated source" do
    dispatch({ "message_id" => "surface-2", "sequence" => 5, "type" => "openui.snapshot",
               "response" => "root = TextContent(\"Canonical\")", "streaming" => false })

    within_surface("surface-2") do
      assert_selector "[data-openui-source]", text: %q{root = TextContent("Canonical")}
    end
  end

  test "completion flips the streaming flag on the renderer" do
    within_surface("surface-2") { assert_selector "[data-openui-rendered][data-openui-streaming='true']" }

    dispatch({ "message_id" => "surface-2", "sequence" => 0, "type" => "openui.completed", "streaming" => false })

    within_surface("surface-2") { assert_selector "[data-openui-rendered][data-openui-streaming='false']" }
  end

  test "a stream error surfaces as an openui:error event" do
    dispatch({ "message_id" => "surface-2", "sequence" => 0, "type" => "openui.error",
               "code" => "provider_rejected", "message" => "nope" })

    assert_selector "body[data-openui-last-error]"
    assert_equal "provider_rejected", read_json("body", "data-openui-last-error")["code"]
  end

  test "a component action round-trips through the Rails endpoint" do
    within_surface("surface-1") { find("[data-openui-action]").click }

    assert_selector "body[data-openui-last-action]"
    detail = read_json("body", "data-openui-last-action")
    assert_equal "surface-1", detail["surfaceId"]
    assert_equal true, detail.dig("result", "value", "ok")
    assert_equal 1, detail.dig("result", "value", "x")
  end

  test "conversation actions preserve the runtime message and form metadata" do
    page.execute_script(<<~JS)
      const element = document.querySelector('[data-openui-surface-id="surface-1"]')
      window.Stimulus.getControllerForElementAndIdentifier(element, "openui").dispatchAction({
        type: "continue_conversation", params: { context: "ticket review" },
        humanFriendlyMessage: "Review this ticket", formName: "reply", formState: { note: "Keep this draft" }
      })
    JS
    assert_selector "body[data-openui-last-action]"
    value = read_json("body", "data-openui-last-action").dig("result", "value")
    assert_equal "Review this ticket", value["message"]
    assert_equal "reply", value["form_name"]
    assert_equal({ "note" => "Keep this draft" }, value["form_state"])
    assert_equal "ticket review", value["context"]
  end

  test "a browser tool call round-trips through the same endpoint" do
    within_surface("surface-1") { find("[data-openui-tool]").click }

    assert_selector "body[data-openui-last-action]"
    detail = read_json("body", "data-openui-last-action")
    assert_equal "x", detail.dig("result", "value", "found")
    assert_selector "body[data-openui-tool-value]"
    assert_equal({ "found" => "x" }, read_json("body", "data-openui-tool-value"))
  end

  test "the Turbo envelope element is consumed and removed" do
    page.execute_script(<<~JS, delta("surface-2", 0, "Z"))
      const surface = document.querySelector(".openui-surface[data-openui-surface-id='surface-2']")
      const element = document.createElement("div")
      element.dataset.controller = "openui-envelope"
      element.dataset.openuiEnvelopePayload = JSON.stringify(arguments[0])
      element.id = "turbo-envelope"
      surface.appendChild(element)
    JS

    within_surface("surface-2") { assert_selector "[data-openui-source]", text: /Z\z/ }
    assert_no_selector "#turbo-envelope", visible: :all
  end

  test "disconnect unmounts the React root" do
    page.execute_script(
      "document.querySelector(\".openui-surface[data-openui-surface-id='surface-2']\").remove()"
    )

    eventually_unmounted = eventually do
      page.evaluate_script("window.__openuiMounts.some((m) => m.unmounted)")
    end

    assert eventually_unmounted
  end
end
