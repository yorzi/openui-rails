# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      class SafetyTest < ActiveSupport::TestCase
        def delta(sequence, text)
          Envelope.delta(message_id: "m", sequence: sequence, delta: text)
        end

        test "completion cannot hide missing deltas" do
          accumulator = Accumulator.new(message_id: "m")
          accumulator.apply(delta(0, "a"))

          assert_equal :gap, accumulator.apply(Envelope.completed(message_id: "m", sequence: 2))
          refute accumulator.completed?
          assert accumulator.needs_snapshot?
        end

        test "a gap pauses all deltas until a current snapshot arrives" do
          accumulator = Accumulator.new(message_id: "m")
          accumulator.apply(delta(0, "a"))
          accumulator.apply(delta(2, "c"))
          accumulator.apply(delta(1, "b"))

          assert_equal "a", accumulator.source
          assert accumulator.needs_snapshot?
        end

        test "stale snapshots and post-completion deltas cannot rewind the UI" do
          accumulator = Accumulator.new(message_id: "m")
          accumulator.apply(delta(0, "a"))
          accumulator.apply(delta(1, "b"))
          accumulator.apply(Envelope.snapshot(message_id: "m", sequence: 0, response: "old"))
          assert_equal "ab", accumulator.source
          accumulator.apply(Envelope.completed(message_id: "m", sequence: 2))
          accumulator.apply(delta(3, "late"))
          assert_equal "ab", accumulator.source
        end

        test "a writer emits exactly one terminal envelope" do
          writer = Bridge.new(message_id: "m").writer
          writer.push("a")
          assert writer.finish.last.completed?
          assert_empty writer.finish
          assert_empty writer.push("late")
          assert_nil writer.error_for(RuntimeError.new("late"))
        end

        test "an errored writer cannot emit more deltas or a completion" do
          writer = Bridge.new(message_id: "m").writer
          assert writer.error_for(RuntimeError.new("failure")).error?
          assert_empty writer.push("late")
          assert_empty writer.finish
        end

        test "consumer failures propagate instead of masquerading as provider errors" do
          calls = 0
          assert_raises(IOError) do
            Bridge.new(message_id: "m").each_envelope([ "hello" ]) do
              calls += 1
              raise IOError, "transport is down"
            end
          end
          assert_equal 1, calls
        end

        test "envelopes cannot be mutated after construction or override routing metadata" do
          text = +"hello"
          envelope = delta(0, text)
          text.replace("changed")
          assert_equal "hello", envelope.delta
          assert_raises(FrozenError) { envelope.delta.replace("other") }
          assert_raises(StreamError) do
            Envelope.new(type: Envelope::DELTA, message_id: "m", sequence: 0,
              data: { "message_id" => "other", "delta" => "text" })
          end
        end
      end
    end
  end
end
