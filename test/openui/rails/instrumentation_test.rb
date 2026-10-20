# frozen_string_literal: true

require "test_helper"

class InstrumentationTest < ActiveSupport::TestCase
  def dispatcher(handler: ->(*) { { secret: "private result" } }, authorize: ->(*) { true })
    registry = OpenUI::Rails::Actions::Registry.new
    registry.register("private.action", schema: {}, authorize: authorize, handler: handler)
    OpenUI::Rails::Actions::Dispatcher.new(registry: registry,
      idempotency_store: OpenUI::Rails::Actions::Idempotency::MemoryStore.new, idempotency_ttl: 60)
  end

  def payload
    { action: "private.action", args: {}, surface_id: "private surface", version: 0, idempotency_key: "private key" }
  end

  def capture(name)
    events = []
    ActiveSupport::Notifications.subscribed(->(event) { events << event.payload.dup }, name) { yield }
    events
  end

  test "action success and replay emit only bounded metadata" do
    subject = dispatcher
    events = capture("action.openui_rails") { 2.times { subject.call(payload, actor: "private actor") } }
    assert_equal %w[succeeded replayed], events.map { |event| event[:outcome] }
    assert_equal [ false, true ], events.map { |event| event[:replayed] }
    events.each do |event|
      assert_equal %i[code duration_ms outcome replayed], event.keys.sort
      assert_nil event[:code]
      assert_operator event[:duration_ms], :>=, 0
      refute_includes event.to_s, "private"
    end
  end

  test "rejected requests and handler failures preserve errors without exception metadata" do
    denied = dispatcher(authorize: ->(*) { false })
    events = capture("action.openui_rails") do
      assert_raises(OpenUI::Rails::UnauthorizedActionError) { denied.call(payload) }
      error = assert_raises(RuntimeError) { dispatcher(handler: ->(*) { raise "private prompt credential" }).call(payload) }
      assert_equal "private prompt credential", error.message
      assert_raises(OpenUI::Rails::InvalidActionError) { denied.call({}) }
    end
    assert_equal %w[rejected failed rejected], events.map { |event| event[:outcome] }
    assert_equal %w[unauthorized internal_error invalid_action], events.map { |event| event[:code] }
    events.each do |event|
      assert_equal %i[code duration_ms outcome replayed], event.keys.sort
      refute_includes event.to_s, "private"
    end
  end

  test "a failing notification subscriber cannot change an action result or exception" do
    ActiveSupport::Notifications.subscribed(->(*) { raise "subscriber failed" }, "action.openui_rails") do
      assert dispatcher.call(payload)
      error = assert_raises(RuntimeError) { dispatcher(handler: ->(*) { raise "handler failed" }).call(payload) }
      assert_equal "handler failed", error.message
    end
    ActiveSupport::Notifications.subscribed(->(*) { raise "subscriber failed" }, "stream.openui_rails") do
      assert OpenUI::Rails::Stream::Bridge.new(message_id: "test").writer.finish.last.completed?
    end
  end

  test "a writer emits one terminal event with sequence bytes and monotonic duration" do
    writer = OpenUI::Rails::Stream::Bridge.new(message_id: "private message").writer
    events = capture("stream.openui_rails") do
      writer.push("private response")
      writer.finish
      writer.finish
      writer.error_for(RuntimeError.new("late credential"))
    end
    assert_equal 1, events.size
    assert_equal({ outcome: "completed", code: nil, sequence: 1, bytes: 16 }, events.first.except(:duration_ms))
    assert_operator events.first[:duration_ms], :>=, 0
    refute_includes events.to_s, "private"
  end

  test "stream errors cancellation and overflow exclude exception and source content" do
    events = capture("stream.openui_rails") do
      %w[provider_rejected stream_cancelled].each do |code|
        OpenUI::Rails::Stream::Bridge.new(message_id: "private").writer.error_for(RuntimeError.new("private token"), code: code)
      end
      config = OpenUI::Rails::Configuration.new
      config.pending_byte_limit = config.stream_byte_limit = 4
      OpenUI::Rails::Stream::Bridge.new(message_id: "private", configuration: config).writer.push("private")
    end
    assert_equal %w[failed cancelled failed], events.map { |event| event[:outcome] }
    assert_equal %w[provider_rejected stream_cancelled stream_too_large], events.map { |event| event[:code] }
    events.each do |event|
      assert_equal %i[bytes code duration_ms outcome sequence], event.keys.sort
      refute_includes event.to_s, "private"
    end
  end
end
