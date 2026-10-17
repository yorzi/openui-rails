# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Actions
      class RegistryTest < ActiveSupport::TestCase
        setup { @registry = Registry.new }

        test "registers and fetches an action" do
          definition = @registry.register("orders.refresh", handler: ->(_invocation) { :ok })

          assert_equal "orders.refresh", definition.name
          assert_equal "orders.refresh", @registry.fetch("orders.refresh").name
          assert @registry.registered?("orders.refresh")
          assert_equal [ "orders.refresh" ], @registry.names
        end

        test "accepts a block as the handler" do
          @registry.register(:refresh) { |_invocation| :ok }

          assert @registry.registered?("refresh")
        end

        test "refetches the latest definition when re-registered" do
          @registry.register("a", handler: ->(_) { 1 })
          @registry.register("a", handler: ->(_) { 2 })

          assert_equal 2, @registry.fetch("a").handler.call(nil)
        end

        test "requires a callable handler" do
          assert_raises(ConfigurationError) { @registry.register("a") }
        end

        test "rejects an invalid action name" do
          assert_raises(ConfigurationError) { @registry.register("bad name", handler: ->(_) { }) }
          assert_raises(ConfigurationError) { @registry.register("1st", handler: ->(_) { }) }
          assert_raises(ConfigurationError) { @registry.register("a" * 100, handler: ->(_) { }) }
        end

        test "raises UnknownActionError for an unregistered action" do
          assert_raises(UnknownActionError) { @registry.fetch("nope") }
        end

        test "converts a Hash schema to a Schema" do
          definition = @registry.register("a", handler: ->(_) { }, schema: { id: Integer })

          assert_instance_of Schema, definition.schema
        end
      end
    end
  end
end
