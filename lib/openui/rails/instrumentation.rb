# frozen_string_literal: true

require "active_support/notifications"

module OpenUI
  module Rails
    # Internal publisher for the documented, content-free notification contract.
    module Instrumentation # :nodoc:
      def self.now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def self.publish(name, started:, **metadata)
        # Do not wrap application code in instrument's block: Active Support
        # would attach the raw exception and its message if that code raised.
        ActiveSupport::Notifications.instrument("#{name}.openui_rails",
          **metadata, duration_ms: (now - started) * 1000)
      rescue StandardError
        # Observability must not change a business result or mask its exception.
        nil
      end

      def self.action_error_code(error)
        case error
        when UnknownActionError then "unknown_action"
        when UnauthorizedActionError then "unauthorized"
        when StaleSurfaceError then "stale_surface"
        when ReplayError then "replay"
        when InvalidActionError then "invalid_action"
        when Error then "error"
        else "internal_error"
        end
      end
    end
  end
end
