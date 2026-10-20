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

  test "network failures have a stable code" do
    page.execute_script("window.fetch = async () => { throw new TypeError('network unavailable') }")
    within_surface("surface-1") { find("[data-openui-action]").click }
    assert_selector "body[data-openui-last-error]"
    assert_equal "network_error", read_json("body", "data-openui-last-error")["code"]
    assert_no_selector "body[data-openui-last-action]"
  end

  test "a late action response cannot report success into a reconnected surface" do
    page.execute_script(<<~JS)
      window.realFetch = window.fetch
      window.fetch = (_url, options) => new Promise(resolve => {
        const body = JSON.parse(options.body)
        window.completeOldAction = () => resolve(new Response(JSON.stringify({result: {
          action: body.action, surface_id: body.surface_id, version: body.version, value: {}, replayed: false
        }}), {headers: {"Content-Type": "application/json"}}))
      })
      const element = document.querySelector('[data-openui-surface-id=surface-1]')
      window.Stimulus.getControllerForElementAndIdentifier(element, 'openui')
        .dispatchAction({action: 'orders.refresh', args: {orderId: 42}})
        .catch(() => {}).finally(() => { window.oldActionSettled = true })
      window.detachedActionSurface = element
      element.remove()
    JS
    assert eventually { page.evaluate_script("window.__openuiMounts.some(mount => mount.unmounted)") }
    page.execute_script("document.body.appendChild(window.detachedActionSurface)")
    within_surface("surface-1") { assert_selector "[data-openui-rendered]" }
    page.execute_script("window.fetch = window.realFetch; window.completeOldAction()")
    assert eventually { page.evaluate_script("window.oldActionSettled === true") }
    assert_no_selector "body[data-openui-last-action]"
    assert_no_selector "body[data-openui-last-error]"
    within_surface("surface-1") { find("[data-openui-action]").click }
    assert_selector "body[data-openui-last-action]"
  end
end
