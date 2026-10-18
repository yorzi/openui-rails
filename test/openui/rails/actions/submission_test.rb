# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Actions
      class SubmissionTest < ActiveSupport::TestCase
        VALID = {
          "action" => "orders.refresh",
          "args" => { "orderId" => 42 },
          "surface_id" => "surface-1",
          "version" => 3,
          "idempotency_key" => "idem-1"
        }.freeze

        test "parses a valid payload" do
          submission = Submission.parse(VALID)

          assert_equal "orders.refresh", submission.action
          assert_equal({ "orderId" => 42 }, submission.args)
          assert_equal "surface-1", submission.surface_id
          assert_equal 3, submission.version
          assert_equal "idem-1", submission.idempotency_key
          refute submission.confirmed?
        end

        test "accepts camelCase aliases and symbol keys" do
          submission = Submission.parse(
            action: :refresh, surfaceId: "s", idempotencyKey: "k", version: 0
          )

          assert_equal "refresh", submission.action
          assert_equal "s", submission.surface_id
          assert_equal "k", submission.idempotency_key
          assert_equal({}, submission.args)
        end

        test "rejects a non-object payload" do
          assert_raises(InvalidActionError) { Submission.parse("nope") }
        end

        test "requires action, surface_id and idempotency_key" do
          %w[action surface_id idempotency_key].each do |key|
            assert_raises(InvalidActionError) { Submission.parse(VALID.merge(key => "")) }
          end
        end

        test "requires a non-negative integer version" do
          assert_raises(InvalidActionError) { Submission.parse(VALID.merge("version" => nil)) }
          assert_raises(InvalidActionError) { Submission.parse(VALID.merge("version" => -1)) }
          assert_raises(InvalidActionError) { Submission.parse(VALID.merge("version" => "3")) }
        end

        test "rejects non-object args" do
          assert_raises(InvalidActionError) { Submission.parse(VALID.merge("args" => "nope")) }
        end

        test "rejects an oversized idempotency key" do
          key = "x" * (Submission::MAX_IDEMPOTENCY_KEY_BYTES + 1)

          assert_raises(InvalidActionError) { Submission.parse(VALID.merge("idempotency_key" => key)) }
        end

        test "args_digest is stable and order-independent" do
          a = Submission.parse(VALID.merge("args" => { "a" => 1, "b" => 2 }))
          b = Submission.parse(VALID.merge("args" => { "b" => 2, "a" => 1 }))
          c = Submission.parse(VALID.merge("args" => { "a" => 1, "b" => 3 }))

          assert_equal a.args_digest, b.args_digest
          refute_equal a.args_digest, c.args_digest
        end

        test "nested symbol and string args produce the same canonical digest" do
          a = Submission.parse(VALID.merge("args" => { outer: { b: 2, a: 1 } }))
          b = Submission.parse(VALID.merge("args" => { "outer" => { "a" => 1, "b" => 2 } }))
          c = Submission.parse(VALID.merge("args" => { outer: { b: 3, a: 1 } }))

          assert_equal a.args_digest, b.args_digest
          refute_equal a.args_digest, c.args_digest
          assert_equal({ "outer" => { "a" => 1, "b" => 2 } }, a.args)
        end

        test "copies and deeply freezes the submission" do
          args = { "nested" => [ +"original" ] }
          submission = Submission.parse(VALID.merge("args" => args))
          args["nested"].first.replace("changed")

          assert_equal "original", submission.args["nested"].first
          assert_raises(FrozenError) { submission.args["nested"] << "other" }
          assert_raises(FrozenError) { submission.action.replace("other") }
        end

        test "false is not an argument object or explicit confirmation" do
          assert_raises(InvalidActionError) { Submission.parse(VALID.merge("args" => false)) }
          refute Submission.new(**VALID.transform_keys(&:to_sym), confirmed: "true").confirmed?
        end
      end
    end
  end
end
