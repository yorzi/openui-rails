# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      module Transports
        class TurboStreamsTest < ActiveSupport::TestCase
          class FakeChannel
            attr_reader :calls

            def initialize = @calls = []

            def broadcast_append_to(*stream, **options)
              calls << [ stream, options ]
            end
          end

          setup do
            @channel = FakeChannel.new
            @transport = TurboStreams.new("surface:1", target: "openui-surface-1", turbo: @channel)
          end

          def envelope(delta: "title = TextContent(\"Hi\")")
            Envelope.delta(message_id: "msg-1", sequence: 0, delta: delta, library_version: "sha256:x")
          end

          test "broadcasts an append action to the target with an envelope element" do
            @transport.broadcast(envelope)

            stream, options = @channel.calls.first
            assert_equal [ "surface:1" ], stream
            assert_equal "openui-surface-1", options[:target]
            assert_includes options[:content], 'data-controller="openui-envelope"'
            assert_includes options[:content], 'data-openui-envelope-payload="'
          end

          test "the element carries the JSON envelope with HTML escaped" do
            html = @transport.element(envelope(delta: %q{root = Text("</div><script>alert(1)</script>")}))

            refute_includes html, "<script>alert(1)</script>"
            assert_includes html, "&quot;"
            assert_includes html, "openui-envelope-payload"
          end

          test "requires a stream and a target" do
            assert_raises(ConfigurationError) { TurboStreams.new(nil, target: "x") }
            assert_raises(ConfigurationError) { TurboStreams.new("s", target: nil) }
            assert_raises(ConfigurationError) { TurboStreams.new("s", target: "") }
          end
        end
      end
    end
  end
end
