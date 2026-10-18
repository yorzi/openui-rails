# frozen_string_literal: true

require "openui/rails/stream/transports/memory"
require "openui/rails/stream/transports/action_cable"
require "openui/rails/stream/transports/turbo_streams"

module OpenUI
  module Rails
    module Stream
      # Transport wrappers for {Broadcaster}. Each responds to
      # `#broadcast(envelope)` and is intentionally thin: sequencing, coalescing
      # and size limits live in {Bridge}, not here.
      module Transports
        module_function

        # Build a transport from a configured name.
        #
        # @param name [Symbol] :action_cable, :turbo / :turbo_streams or :memory
        # @param options [Hash] forwarded to the transport constructor
        def build(name, **options)
          case name.to_sym
          when :action_cable
            ActionCable.new(options.delete(:stream_name), **options)
          when :turbo, :turbo_streams
            TurboStreams.new(options.delete(:stream), **options)
          when :memory
            Memory.new(**options)
          else
            raise ConfigurationError,
                  "unsupported transport #{name.inspect}; expected one of [:action_cable, :turbo, :memory]"
          end
        end
      end
    end
  end
end
