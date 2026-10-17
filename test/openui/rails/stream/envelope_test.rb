# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      class EnvelopeTest < ActiveSupport::TestCase
        test "delta serializes the documented wire shape" do
          envelope = Envelope.delta(
            message_id: "msg-1", sequence: 12, delta: 'title = TextContent("Hello")',
            library_version: "sha256:abc"
          )

          assert_equal(
            {
              "message_id" => "msg-1",
              "sequence" => 12,
              "type" => "openui.delta",
              "library_version" => "sha256:abc",
              "delta" => 'title = TextContent("Hello")',
              "streaming" => true
            },
            envelope.to_h
          )
          assert_equal envelope.to_h, JSON.parse(envelope.to_json)
        end

        test "library_version is omitted when nil" do
          refute Envelope.completed(message_id: "m", sequence: 0).to_h.key?("library_version")
        end

        test "snapshot carries the full response" do
          envelope = Envelope.snapshot(message_id: "m", sequence: 3, response: "root = Card()")

          assert envelope.snapshot?
          assert_equal "root = Card()", envelope.response
          refute envelope.streaming?
        end

        test "completed and error builders" do
          assert Envelope.completed(message_id: "m", sequence: 5).completed?

          error = Envelope.error(message_id: "m", sequence: 5, code: "provider_rejected", message: "boom")
          assert error.error?
          assert_equal "provider_rejected", error.code
        end

        test "rejects an unknown type" do
          assert_raises(StreamError) do
            Envelope.new(type: "openui.nope", message_id: "m", sequence: 0)
          end
        end

        test "rejects an unknown error code" do
          assert_raises(StreamError) do
            Envelope.error(message_id: "m", sequence: 0, code: "made_up")
          end
        end

        test "rejects a blank or oversized message_id" do
          assert_raises(StreamError) { Envelope.completed(message_id: "", sequence: 0) }
          assert_raises(StreamError) do
            Envelope.completed(message_id: "x" * (Envelope::MAX_MESSAGE_ID_BYTES + 1), sequence: 0)
          end
        end

        test "rejects a negative or non-integer sequence" do
          assert_raises(StreamError) { Envelope.completed(message_id: "m", sequence: -1) }
          assert_raises(StreamError) { Envelope.completed(message_id: "m", sequence: "0") }
        end

        test "rejects a non-string delta" do
          assert_raises(StreamError) { Envelope.delta(message_id: "m", sequence: 0, delta: nil) }
        end

        test "equality is by payload" do
          a = Envelope.completed(message_id: "m", sequence: 1)
          b = Envelope.completed(message_id: "m", sequence: 1)

          assert_equal a, b
          assert_equal a.hash, b.hash
        end
      end
    end
  end
end
