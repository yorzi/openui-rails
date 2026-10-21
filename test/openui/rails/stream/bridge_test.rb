# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      class BridgeTest < ActiveSupport::TestCase
        setup do
          OpenUI::Rails.reset_configuration!
          @configuration = OpenUI::Rails.configuration
          @configuration.pending_byte_limit = 4
          @configuration.stream_byte_limit = 64
        end

        teardown do
          OpenUI::Rails.reset_configuration!
        end

        def bridge(library_version: "sha256:abc")
          Bridge.new(message_id: "msg-1", library_version: library_version, configuration: @configuration)
        end

        test "coalesces chunks up to the pending limit then flushes the remainder" do
          envelopes = bridge.envelopes([ "ab", "cd", "ef", "g" ]).to_a

          assert_equal [ "abcd", "efg" ], envelopes.select(&:delta?).map(&:delta)
          assert_equal [ 0, 1 ], envelopes.select(&:delta?).map(&:sequence)
          assert envelopes.last.completed?
          assert_equal 2, envelopes.last.sequence
        end

        test "assigns contiguous, ordered sequences" do
          envelopes = bridge.envelopes([ "aaaa", "bbbb", "cccc" ]).to_a

          assert_equal [ 0, 1, 2, 3 ], envelopes.map(&:sequence)
          assert envelopes.last.completed?
        end

        test "skips nil and empty chunks" do
          envelopes = bridge.envelopes([ nil, "", "abc", nil ]).to_a

          assert_equal [ "abc" ], envelopes.select(&:delta?).map(&:delta)
        end

        test "an empty source still completes" do
          envelopes = bridge.envelopes([]).to_a

          assert_equal 1, envelopes.size
          assert envelopes.first.completed?
        end

        test "every envelope carries the library version" do
          envelopes = bridge.envelopes([ "data" ]).to_a

          assert envelopes.all? { |envelope| envelope.library_version == "sha256:abc" }
        end

        test "enforces the stream byte limit and stops with an error" do
          @configuration.stream_byte_limit = 8
          @configuration.pending_byte_limit = 4

          envelopes = bridge.envelopes([ "aaaa", "bbbb", "cc" ]).to_a

          assert_equal "stream_too_large", envelopes.last.code
          assert envelopes.last.error?
          refute envelopes.any?(&:completed?)
        end

        test "stops pulling the source once the byte limit ends the stream" do
          @configuration.stream_byte_limit = 8
          @configuration.pending_byte_limit = 4
          pulled = 0
          source = Enumerator.new { |chunks| 100.times { pulled += 1; chunks << "aaaa" } }

          envelopes = bridge.envelopes(source).to_a

          assert_equal "stream_too_large", envelopes.last.code
          assert_equal 3, pulled
        end

        test "surfaces a source failure as a structured, sanitized error envelope" do
          seen = nil
          @configuration.on_error = ->(error, message_id:) { seen = [ error.class, message_id ] }

          failing = Class.new do
            def each
              yield "a"
              raise "provider exploded with prompt secret"
            end
          end

          envelopes = bridge.envelopes(failing.new).to_a
          error = envelopes.last

          assert error.error?
          assert_equal "stream_failed", error.code
          refute_includes error.to_h.to_s, "prompt secret"
          assert_equal [ RuntimeError, "msg-1" ], seen
        end
      end
    end
  end
end
