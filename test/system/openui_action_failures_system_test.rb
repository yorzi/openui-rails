# frozen_string_literal: true

require "application_system_test_case"

class OpenUIActionFailuresSystemTest < ApplicationSystemTestCase
  setup do
    visit "/demo"
    within_surface("surface-1") { assert_selector "[data-openui-action]" }
    install_recorders
  end

  test "an expired-session redirect never reports action success" do
    page.execute_script("document.querySelector('[data-openui-surface-id=surface-1]').dataset.openuiActionsUrl = '/expired-session'")
    within_surface("surface-1") { find("[data-openui-action]").click }

    assert_selector "body[data-openui-last-error]"
    assert_equal "unauthorized", read_json("body", "data-openui-last-error")["code"]
    assert_no_selector "body[data-openui-last-action]"
  end

  test "malformed JSON and unrelated response results are not successful actions" do
    [ "not json", '{"result":{"action":"other","surface_id":"surface-1","version":2}}' ].each do |body|
      page.execute_script(<<~JS, body)
        const responseBody = arguments[0]
        window.fetch = async () => new Response(responseBody, { status: 200, headers: { "Content-Type": "application/json" } })
        delete document.body.dataset.openuiLastError
      JS
      within_surface("surface-1") { find("[data-openui-action]").click }
      assert_selector "body[data-openui-last-error]"
      assert_equal "invalid_response", read_json("body", "data-openui-last-error")["code"]
      assert_no_selector "body[data-openui-last-action]"
    end
  end
end
