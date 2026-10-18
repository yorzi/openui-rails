# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Stream
      module Transports
        class ActionCableTest < ActiveSupport::TestCase
          FakeServer = Struct.new(:calls) do
            def initialize = super([])

            def broadcast(stream_name, payload)
              calls << [ stream_name, payload ]
            end
          end

          setup do
            @server = FakeServer.new
          end

          def envelope
            Envelope.delta(message_id: "msg-1", sequence: 0, delta: "ab", library_version: "sha256:x")
          end

          test "broadcasts the envelope hash to the configured stream" do
            transport = ActionCable.new("openui:surface:1", cable: @server)

            transport.broadcast(envelope)

            assert_equal [ [ "openui:surface:1", envelope.to_h ] ], @server.calls
          end

          test "coerces the stream name to a string" do
            transport = ActionCable.new(:surface_1, cable: @server)

            assert_equal "surface_1", transport.stream_name
          end

          test "requires a stream name" do
            assert_raises(ConfigurationError) { ActionCable.new(nil) }
            assert_raises(ConfigurationError) { ActionCable.new("") }
          end
        end
      end
    end
  end
end
