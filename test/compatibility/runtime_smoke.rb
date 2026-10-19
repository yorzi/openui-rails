# frozen_string_literal: true

require "application_system_test_case"
require "tempfile"

raise "Set OPENUI_REAL_RUNTIME_DIR to the checksum-verified runtime directory" unless ENV["OPENUI_REAL_RUNTIME_DIR"]

class RealRuntimeCompatibilityTest < ApplicationSystemTestCase
  setup do
    # Derive the spec from this exact bundle, then verify the next mount against
    # that spec (the same workflow a host must use for its prompt generation).
    visit "/demo"
    assert_text "Hello from OpenUI"
    @spec = Tempfile.new([ "openui-chat", ".json" ])
    @spec.write(page.evaluate_script("JSON.stringify(window.__OpenUI.openuiChatLibrary.toSpec())"))
    @spec.flush
    OpenUI::Rails.configure { |config| config.library_spec_path = @spec.path }
  end

  teardown do
    OpenUI::Rails.configure { |config| config.library_spec_path = nil }
    @spec&.close!
  end
  test "the pinned real renderer renders the Rails surface and stylesheet" do
    visit "/demo"
    assert_selector "[data-openui-surface-id='surface-1']", visible: :all
    assert_text "Hello from OpenUI"
    assert_selector "link[href='/audit-runtime/runtime.css'][integrity]", visible: :all
    assert page.evaluate_script("!!window.__OpenUI.React && !!window.__OpenUI.Renderer")
    assert_no_selector "script[src*='cdn.jsdelivr.net']", visible: :all
  end

  test "shipped default-library exports match the actual browser runtime" do
    library = page.evaluate_script("({ prompt: window.__OpenUI.openuiChatLibrary.prompt(), spec: window.__OpenUI.openuiChatLibrary.toSpec() })")
    files = OpenUI::Rails::DefaultLibrary.files

    assert_equal files.fetch("library.prompt.txt"), library.fetch("prompt").b
    assert_equal JSON.parse(files.fetch("library.spec.json")), library.fetch("spec")
  end

  test "a real component action reaches Rails through the official type and params shape" do
    visit "/demo"
    assert_text "Hello from OpenUI"
    install_recorders
    dispatch({ "message_id" => "surface-1", "sequence" => 0, "type" => "openui.snapshot",
               "response" => 'root = Card([Buttons([Button("Real action", @ToAssistant("Hello Rails"))])])' })
    # Verify actual keyboard focus and activation, not only DOM attributes.
    find("body").send_keys(:tab)
    assert_equal "Real action", page.evaluate_script("document.activeElement.textContent")
    page.driver.browser.action.send_keys(:enter).perform

    assert_selector "body[data-openui-last-action]"
    detail = read_json("body", "data-openui-last-action")
    assert_equal "continue_conversation", detail.dig("result", "action")
    assert_equal "Hello Rails", detail.dig("result", "value", "message")
    assert_no_selector "body[data-openui-last-error]"
  end

  test "a real Mutation executes only after its button is activated" do
    visit "/demo"
    assert_text "Hello from OpenUI"
    install_recorders
    dispatch({ "message_id" => "surface-1", "sequence" => 0, "type" => "openui.snapshot",
               "response" => "result = Mutation(\"do.thing\", {x: 1})\nroot = Card([Buttons([Button(\"Execute mutation\", @Run(result))])])" })
    assert_button "Execute mutation"
    assert_no_selector "body[data-openui-last-action]"
    click_button "Execute mutation"
    assert_selector "body[data-openui-last-action]"
    assert_equal true, read_json("body", "data-openui-last-action").dig("result", "value", "ok")
    assert_no_selector "body[data-openui-last-error]"
  end

  test "a real Query uses the Rails tool bridge and renders the handler value" do
    visit "/demo"
    assert_text "Hello from OpenUI"
    install_recorders
    dispatch({ "message_id" => "surface-1", "sequence" => 0, "type" => "openui.snapshot",
               "response" => "data = Query(\"Lookup\", {q: \"verified tool\"}, {found: \"Loading\"})\nroot = Card([TextContent(data.found)])" })

    assert_text "verified tool"
    assert_selector "body[data-openui-last-action]"
    assert_no_selector "body[data-openui-last-error]"
  end

  test "unknown components report a renderer error rather than executing JavaScript" do
    visit "/demo"
    assert_text "Hello from OpenUI"
    install_recorders
    dispatch({ "message_id" => "surface-1", "sequence" => 0, "type" => "openui.snapshot",
               "response" => 'root = Card([UnknownComponent("<script>window.openuiInjected = true</script>")])' })

    assert_selector "body[data-openui-last-error]"
    assert_equal "renderer_error", read_json("body", "data-openui-last-error")["code"]
    assert_nil page.evaluate_script("window.openuiInjected")
    assert_no_selector "[data-openui-surface-id='surface-1'] script", visible: :all
  end
end
