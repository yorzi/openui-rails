# frozen_string_literal: true

require "application_system_test_case"

class OpenUITurboSystemTest < ApplicationSystemTestCase
  test "a Turbo visit and back navigation restore source without duplicate roots" do
    visit "/demo"
    within_surface("surface-2") { assert_selector "[data-openui-rendered]" }
    dispatch(delta("surface-2", 0, "A"))
    before = source_of("surface-2")
    click_link "Visit demo again"
    assert_current_path "/demo?visit=next"
    within_surface("surface-2") { assert_selector "[data-openui-rendered]" }
    page.go_back
    assert_current_path "/demo"
    within_surface("surface-2") { assert_selector "[data-openui-rendered]" }

    within_surface("surface-2") { assert_selector "[data-openui-source]", text: before }
    assert_selector "[data-openui-rendered]", count: 2
    dispatch(delta("surface-2", 1, "B"))
    within_surface("surface-2") { assert_selector "[data-openui-source]", text: /AB\z/ }
  end

  test "a real Turbo Streams broadcast crosses Action Cable and updates the island" do
    visit "/demo?transport=turbo"
    assert_selector "turbo-cable-stream-source[connected]", visible: :all
    within_surface("surface-2") { assert_selector "[data-openui-rendered]" }

    transport = OpenUI::Rails::Stream::Transports::TurboStreams.new("openui-demo", target: "openui-envelope-inbox")
    transport.broadcast(OpenUI::Rails::Stream::Envelope.delta(message_id: "surface-2", sequence: 0, delta: " via cable"))

    within_surface("surface-2") { assert_selector "[data-openui-source]", text: /via cable\z/ }
    assert_no_selector "#openui-envelope-inbox [data-controller='openui-envelope']", visible: :all
  end
end
