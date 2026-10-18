# frozen_string_literal: true

require "application_system_test_case"

# Smoke test: the harness boots, the pinned runtime is loaded lazily, and a
# static surface renders through the stimulus controller.
class OpenUISmokeSystemTest < ApplicationSystemTestCase
  test "a static surface renders through the runtime" do
    visit "/demo"

    assert_selector ".openui-surface[data-openui-surface-id='surface-1']"
    within ".openui-surface[data-openui-surface-id='surface-1']" do
      assert_selector "[data-openui-rendered='true']"
      assert_selector "[data-openui-source]", text: "Hello from OpenUI"
      assert_selector "[data-openui-rendered][data-openui-library='stub-chat-library']"
    end
  end
end
