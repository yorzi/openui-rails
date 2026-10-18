# frozen_string_literal: true

require "erb"
require "json"

module OpenUI
  module Rails
    module Stream
      module Transports
        # Broadcasts each envelope as a Turbo Stream that appends an
        # `openui-envelope` element to a target already in the DOM.
        #
        # The small `openui-envelope` Stimulus controller turns that element
        # into an `openui:envelope` event and removes itself, so no inline
        # script is used and no Content Security Policy relaxation is needed.
        #
        # turbo-rails is looked up lazily and may be injected via `turbo:`; the
        # Gem never hard-depends on it.
        class TurboStreams
          ELEMENT_TAG = "div"

          attr_reader :stream, :target

          def initialize(stream, target:, turbo: nil)
            raise ConfigurationError, "a stream is required" if stream.nil?
            if target.nil? || target.to_s.empty?
              raise ConfigurationError, "a target is required"
            end

            @stream = stream
            @target = target.to_s
            @turbo = turbo
          end

          def broadcast(envelope)
            channel.broadcast_append_to(stream, target: target, content: element(envelope))
          end

          # The HTML fragment a Turbo Stream appends. Kept public so tests can
          # assert on escaping without a Turbo dependency.
          def element(envelope)
            payload = ERB::Util.html_escape(JSON.generate(envelope.to_h))
            %(<#{ELEMENT_TAG} data-controller="openui-envelope" data-openui-envelope-payload="#{payload}"></#{ELEMENT_TAG}>)
          end

          private

          def channel
            return @turbo if @turbo

            unless defined?(::Turbo::StreamsChannel)
              raise StreamError, "Turbo Streams is not loaded; add turbo-rails or use another transport"
            end

            ::Turbo::StreamsChannel
          end
        end
      end
    end
  end
end
