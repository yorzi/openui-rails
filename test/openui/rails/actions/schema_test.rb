# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Actions
      class SchemaTest < ActiveSupport::TestCase
        test "accepts a valid object" do
          schema = Schema.define(required: { order_id: Integer }, optional: { note: [ String, NilClass ] })

          assert_equal({ "order_id" => 1 }, schema.validate!({ "order_id" => 1 }))
        end

        test "rejects a non-object" do
          assert_raises(InvalidActionError) { Schema.any.validate!("nope") }
        end

        test "reports a missing required argument" do
          schema = Schema.define(required: { order_id: Integer })

          error = assert_raises(InvalidActionError) { schema.validate!({}) }
          assert_match(/order_id/, error.message)
        end

        test "reports a wrong type" do
          schema = Schema.define(required: { order_id: Integer })

          assert_raises(InvalidActionError) { schema.validate!({ order_id: "x" }) }
        end

        test "rejects unknown arguments unless allowed" do
          schema = Schema.define(required: { order_id: Integer })

          assert_raises(InvalidActionError) { schema.validate!({ order_id: 1, secret: true }) }
          assert_equal({ order_id: 1, extra: true },
                       Schema.define(required: { order_id: Integer }, allow_extra: true).validate!({ order_id: 1, extra: true }))
        end

        test "supports Regexp and callable expectations" do
          schema = Schema.define(required: { id: /\Aord_\d+\z/, count: ->(value) { value.positive? } })

          assert schema.validate!({ id: "ord_12", count: 3 })
          assert_raises(InvalidActionError) { schema.validate!({ id: "nope", count: 3 }) }
          assert_raises(InvalidActionError) { schema.validate!({ id: "ord_12", count: -1 }) }
        end

        test "builds from a Hash, Schema or callable" do
          assert_instance_of Schema, Schema.from({ a: Integer })
          assert_instance_of Schema, Schema.from(Schema.any)
          assert_instance_of Schema::Callable, Schema.from(->(args) { args.key?("a") })
          assert_equal true, Schema.any.allow_extra?
        end

        test "a falsey callable rejects the args" do
          schema = Schema.from(->(_args) { false })

          assert_raises(InvalidActionError) { schema.validate!({ a: 1 }) }
        end
      end
    end
  end
end
