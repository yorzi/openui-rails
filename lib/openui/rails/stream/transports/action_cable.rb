# frozen_string_literal: true

module OpenUI
  module Rails
    module Stream
      module Transports
        # Broadcasts envelope hashes over Action Cable.
        #
        # The stream name is supplied by the host (the Gem does not invent a
        # tenant-scoping scheme). Pair it with a channel that dispatches each
        # received payload as an `openui:envelope` event on the page. See the
        # "Transports" section of the README. Authorization for the subscription
        # stays in the host's channel.
        #
        # `cable:` is the Action Cable server (or a test double that responds to
        # `#broadcast`), injectable so this can be exercised without a running
        # Action Cable server.
        class ActionCable
          attr_reader :stream_name

          def initialize(stream_name, cable: nil)
            if stream_name.nil? || stream_name.to_s.empty?
              raise ConfigurationError, "a stream_name is required"
            end

            @stream_name = stream_name.to_s
            @cable = cable
          end

          # @return [Object] the result of the underlying broadcast
          def broadcast(envelope)
            server.broadcast(stream_name, envelope.to_h)
          end

          private

          def server
            return @cable if @cable

            unless defined?(::ActionCable) && ::ActionCable.respond_to?(:server)
              raise StreamError, "Action Cable is not loaded; add actioncable or use another transport"
            end

            ::ActionCable.server
          end
        end
      end
    end
  end
end
