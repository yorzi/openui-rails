# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Actions
      class DispatcherTest < ActiveSupport::TestCase
        Surface = Struct.new(:id, :version)

        setup do
          @registry = Registry.new
          @store = Idempotency::MemoryStore.new
          @calls = []
        end

        def dispatcher(authorize_action: nil, surface_resolver: nil)
          Dispatcher.new(
            registry: @registry, idempotency_store: @store, idempotency_ttl: 900,
            authorize_action: authorize_action, surface_resolver: surface_resolver
          )
        end

        def register(name, authorize: ->(_invocation) { true }, **options, &handler)
          @registry.register(name, handler: handler, authorize: authorize, **options)
        end

        def payload(**overrides)
          {
            "action" => "orders.refresh", "args" => { "orderId" => 42 }, "surface_id" => "surface-1",
            "version" => 1, "idempotency_key" => "idem-1"
          }.merge(overrides.transform_keys(&:to_s))
        end

        test "executes a permitted action once and returns its value" do
          register("orders.refresh") { |invocation| @calls << invocation; { status: "ok" } }

          result = dispatcher.call(payload)

          assert_equal "orders.refresh", result.action
          assert_equal({ status: "ok" }, result.value)
          refute result.replayed?
          assert_equal 1, @calls.size
        end

        test "passes actor, surface, tenant and context to the handler" do
          surface = Surface.new("surface-1", 1)
          captured = nil
          register("orders.refresh") { |invocation| captured = invocation }

          dispatcher(surface_resolver: ->(_id, **) { surface }).call(
            payload, actor: :andy, tenant: :acme, context: { message_id: "m" }
          )

          assert_equal :andy, captured.actor
          assert_equal :acme, captured.tenant
          assert_equal surface, captured.surface
          assert_equal "m", captured.message_id
        end

        test "rejects an unknown action without side effects" do
          assert_raises(UnknownActionError) { dispatcher.call(payload) }
          assert_empty @calls
        end

        test "rejects args that fail the schema" do
          register("orders.refresh", schema: { orderId: Integer }) { |_invocation| @calls << :called }

          assert_raises(InvalidActionError) { dispatcher.call(payload("args" => { "orderId" => "x" })) }
          assert_empty @calls
        end

        test "requires explicit confirmation for a destructive action" do
          register("orders.cancel", confirmation: true) { |_invocation| @calls << :called }

          assert_raises(InvalidActionError) { dispatcher.call(payload("action" => "orders.cancel")) }
          assert_empty @calls

          assert dispatcher.call(payload("action" => "orders.cancel", "confirmed" => true))
          assert_equal [ :called ], @calls
        end

        test "rejects a stale surface revision" do
          register("orders.refresh") { |_invocation| @calls << :called }
          surface = Surface.new("surface-1", 5)

          assert_raises(StaleSurfaceError) do
            dispatcher(surface_resolver: ->(_id, **) { surface }).call(payload("version" => 4))
          end
          assert_empty @calls
        end

        test "accepts a current surface revision" do
          register("orders.refresh") { |_invocation| @calls << :called }
          surface = Surface.new("surface-1", 4)

          dispatcher(surface_resolver: ->(_id, **) { surface }).call(payload("version" => 4))

          assert_equal [ :called ], @calls
        end

        test "denies an action the authorizer rejects" do
          register("orders.refresh", authorize: ->(_invocation) { false }) { |_invocation| @calls << :called }

          assert_raises(UnauthorizedActionError) { dispatcher.call(payload) }
          assert_empty @calls
        end

        test "fails closed when no authorizer is configured" do
          register("orders.refresh", authorize: nil) { |_invocation| @calls << :called }

          assert_raises(UnauthorizedActionError) { dispatcher.call(payload) }
          assert_empty @calls
        end

        test "falls back to a global authorizer" do
          @registry.register("orders.refresh", handler: ->(_invocation) { @calls << :called })
          fallback = ->(_invocation) { false }

          assert_raises(UnauthorizedActionError) { dispatcher(authorize_action: fallback).call(payload) }
        end

        test "rejects an inaccessible surface" do
          register("orders.refresh") { |_invocation| @calls << :called }

          assert_raises(UnauthorizedActionError) do
            dispatcher(surface_resolver: ->(_id, **) { nil }).call(payload)
          end
          assert_empty @calls
        end

        test "a duplicate submission replays the stored result without re-executing" do
          register("orders.refresh") { |_invocation| @calls << :called; "value" }
          subject = dispatcher

          first = subject.call(payload)
          second = subject.call(payload)

          refute first.replayed?
          assert second.replayed?
          assert_equal "value", second.value
          assert_equal 1, @calls.size
        end

        test "reusing an idempotency key with different args is a replay error" do
          register("orders.refresh") { |_invocation| @calls << :called; "value" }
          subject = dispatcher

          subject.call(payload)
          assert_raises(ReplayError) { subject.call(payload("args" => { "orderId" => 99 })) }
          assert_equal 1, @calls.size
        end

        test "distinct idempotency keys execute independently" do
          register("orders.refresh") { |_invocation| @calls << :called }
          subject = dispatcher

          subject.call(payload("idempotency_key" => "a"))
          subject.call(payload("idempotency_key" => "b"))

          assert_equal 2, @calls.size
        end

        test "a key cannot replay a result from another action or surface" do
          register("orders.refresh") { "private refresh result" }
          register("orders.cancel") { @calls << :cancelled }
          subject = dispatcher
          subject.call(payload)

          assert_raises(ReplayError) { subject.call(payload(action: "orders.cancel")) }
          assert_raises(ReplayError) { subject.call(payload(surface_id: "other")) }
          assert_empty @calls
        end

        test "different actors never share cached results" do
          register("orders.refresh") { |invocation| invocation.actor }
          subject = dispatcher

          assert_equal :alice, subject.call(payload, actor: :alice).value
          assert_equal :bob, subject.call(payload, actor: :bob).value
        end

        test "different tenants never share cached results" do
          register("orders.refresh") { |invocation| invocation.tenant }
          subject = dispatcher

          assert_equal :acme, subject.call(payload, actor: :alice, tenant: :acme).value
          assert_equal :other, subject.call(payload, actor: :alice, tenant: :other).value
        end

        test "a resolver cannot substitute a different surface" do
          register("orders.refresh") { @calls << :called }

          assert_raises(UnauthorizedActionError) do
            dispatcher(surface_resolver: ->(*) { Surface.new("wrong", 1) }).call(payload)
          end
          assert_empty @calls
        end

        test "nil and false handler results are replayable" do
          [ nil, false ].each_with_index do |value, index|
            register("orders.refresh") { @calls << :called; value }
            subject = dispatcher
            submission = payload(idempotency_key: "nullable-#{index}")
            subject.call(submission)
            replay = subject.call(submission)

            assert replay.replayed?
            value.nil? ? assert_nil(replay.value) : assert_equal(value, replay.value)
          end
          assert_equal 2, @calls.size
        end
      end
    end
  end
end
