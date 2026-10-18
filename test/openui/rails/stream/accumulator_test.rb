# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      class AccumulatorTest < ActiveSupport::TestCase
        setup do
          @accumulator = Accumulator.new(message_id: "msg-1")
        end

        def delta(sequence, text)
          Envelope.delta(message_id: "msg-1", sequence: sequence, delta: text)
        end

        test "applies ordered deltas" do
          assert_equal :applied, @accumulator.apply(delta(0, "a"))
          assert_equal :applied, @accumulator.apply(delta(1, "b"))

          assert_equal "ab", @accumulator.source
          assert_equal 2, @accumulator.next_sequence
        end

        test "ignores duplicate and stale sequences" do
          @accumulator.apply(delta(0, "a"))

          assert_equal :duplicate, @accumulator.apply(delta(0, "a"))
          assert_equal :duplicate, @accumulator.apply(delta(0, "zzz"))
          assert_equal "a", @accumulator.source
        end

        test "a gap demands a snapshot without appending" do
          @accumulator.apply(delta(0, "a"))

          assert_equal :gap, @accumulator.apply(delta(2, "c"))
          assert_equal "a", @accumulator.source
          assert @accumulator.needs_snapshot?
        end

        test "a snapshot replaces the source and clears the gap" do
          @accumulator.apply(delta(0, "a"))
          @accumulator.apply(delta(2, "c"))

          assert_equal :snapshot, @accumulator.apply(
            Envelope.snapshot(message_id: "msg-1", sequence: 0, response: "authoritative", streaming: true)
          )

          assert_equal "authoritative", @accumulator.source
          assert_equal 1, @accumulator.next_sequence
          refute @accumulator.needs_snapshot?
          assert_equal :applied, @accumulator.apply(delta(1, "!"))
          assert_equal "authoritative!", @accumulator.source
        end

        test "completed sets the finished flag" do
          assert_equal :completed, @accumulator.apply(Envelope.completed(message_id: "msg-1", sequence: 0))

          assert @accumulator.completed?
          assert_equal 1, @accumulator.next_sequence
        end

        test "error records the failing envelope" do
          assert_equal :error, @accumulator.apply(
            Envelope.error(message_id: "msg-1", sequence: 0, code: "stream_failed")
          )

          assert @accumulator.error?
          assert_equal "stream_failed", @accumulator.error.code
        end

        test "ignores envelopes for another message" do
          assert_equal :ignored, @accumulator.apply(
            Envelope.delta(message_id: "other", sequence: 0, delta: "x")
          )
          assert_equal "", @accumulator.source
        end
      end
    end
  end
end
