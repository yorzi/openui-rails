# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      class BroadcasterTest < ActiveSupport::TestCase
        setup do
          OpenUI::Rails.reset_configuration!
          @configuration = OpenUI::Rails.configuration
          # Flush every 4 bytes so the tests can drive the writer deterministically.
          @configuration.pending_byte_limit = 4
          @configuration.stream_byte_limit = 64
          @transport = Transports::Memory.new
        end

        teardown do
          OpenUI::Rails.reset_configuration!
        end

        def broadcaster(message_id: "msg-1")
          Broadcaster.new(
            transport: @transport,
            message_id: message_id,
            library_version: "sha256:abc",
            configuration: @configuration
          )
        end

        test "broadcasts ordered envelopes as chunks flush" do
          subject = broadcaster

          subject.push("ab")
          assert_empty @transport.envelopes, "nothing flushes below the pending limit"

          subject.push("cd") # reaches the 4-byte pending limit
          assert_equal 1, @transport.envelopes.size
          assert_equal "abcd", @transport.envelopes.first.delta

          subject.push("ef").finish

          assert_equal [ "abcd", "ef" ], @transport.envelopes.select(&:delta?).map(&:delta)
          assert_equal [ 0, 1, 2 ], @transport.envelopes.map(&:sequence)
          assert @transport.envelopes.last.completed?
        end

        test "broadcast stops reading the source after the byte limit" do
          @configuration.stream_byte_limit = 8
          pulled = 0
          source = Enumerator.new { |chunks| 100.times { pulled += 1; chunks << "aaaa" } }

          Broadcaster.broadcast(source, transport: @transport, message_id: "msg-1", configuration: @configuration)

          assert_equal 3, pulled
          assert_equal "stream_too_large", @transport.envelopes.last.code
        end

        test "push and finish return self for chaining" do
          subject = broadcaster

          assert_same subject, subject.push("abcd")
          assert_same subject, subject.finish
        end

        test "fail broadcasts a structured, PII-free error envelope" do
          errors = []
          @configuration.on_error = ->(error, message_id:) { errors << [ error.message, message_id ] }

          subject = broadcaster
          subject.fail(StandardError.new("provider exploded"), code: "provider_rejected")

          envelope = @transport.envelopes.last
          assert envelope.error?
          assert_equal "provider_rejected", envelope.code
          refute_includes envelope.to_json, "provider exploded"
          assert_equal [ [ "provider exploded", "msg-1" ] ], errors
        end

        test "rejects a missing transport" do
          error = assert_raises(ConfigurationError) { Broadcaster.new(transport: nil, message_id: "m") }
          assert_match(/transport is required/, error.message)
        end

        test "rejects a transport that does not broadcast" do
          error = assert_raises(ConfigurationError) { Broadcaster.new(transport: Object.new, message_id: "m") }
          assert_match(/#broadcast/, error.message)
        end

        test "class-level broadcast consumes an enumerable source" do
          result = Broadcaster.broadcast(
            [ "abcd", "efgh" ],
            transport: @transport,
            message_id: "msg-2",
            library_version: "sha256:abc",
            configuration: @configuration
          )

          assert_instance_of Broadcaster, result
          assert_equal [ "abcd", "efgh" ], @transport.envelopes.select(&:delta?).map(&:delta)
          assert @transport.envelopes.last.completed?
          assert_equal "msg-2", @transport.envelopes.last.message_id
        end
      end
    end
  end
end
