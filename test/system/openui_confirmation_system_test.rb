# frozen_string_literal: true

require "application_system_test_case"

# The `confirmation: true` gate is enforced server-side. These tests prove the
# browser controller forwards the flag faithfully and that a rejected action
# surfaces as an `openui:error` event rather than a silent success.
class OpenUIConfirmationSystemTest < ApplicationSystemTestCase
  setup do
    visit "/demo"
    install_recorders
  end

  test "a destructive action without confirmation is rejected" do
    within_surface("surface-1") { find("[data-openui-action-unconfirmed]").click }

    assert_selector "body[data-openui-last-error]"
    assert_equal "invalid_action", read_json("body", "data-openui-last-error")["code"]
    assert_no_selector "body[data-openui-last-action]"
  end

  test "a destructive action succeeds once confirmation is submitted" do
    within_surface("surface-1") { find("[data-openui-action-confirmed]").click }

    assert_selector "body[data-openui-last-action]"
    detail = read_json("body", "data-openui-last-action")
    assert_equal "surface-1", detail["surfaceId"]
    assert_equal true, detail.dig("result", "value", "deleted")
  end
end
