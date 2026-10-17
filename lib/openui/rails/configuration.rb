# frozen_string_literal: true

module OpenUI
  module Rails
    # Global, process-wide configuration for the gem.
    #
    #   OpenUI::Rails.configure do |config|
    #     config.transport = :turbo
    #     config.library_spec_path = Rails.root.join("config/openui/library.spec.json")
    #     config.runtime_assets = :self_hosted
    #   end
    class Configuration
      TRANSPORTS = %i[turbo action_cable none].freeze
      ASSET_STRATEGIES = %i[self_hosted external].freeze

      DEFAULT_STREAM_BYTE_LIMIT = 1_048_576 # 1 MiB of OpenUI Lang per message
      DEFAULT_PENDING_BYTE_LIMIT = 32_768   # flush threshold while streaming
      DEFAULT_IDEMPOTENCY_TTL = 15 * 60     # seconds
      DEFAULT_ACTIONS_ENDPOINT = "/openui-rails/actions"

      attr_reader :transport, :runtime_assets, :idempotency_store
      attr_accessor :library_spec_path, :prompt_path, :library_name,
                    :actions_endpoint, :surface_id_param,
                    :stream_byte_limit, :pending_byte_limit, :idempotency_ttl,
                    :authorize_action, :on_error, :action_registry, :surface_resolver

      def initialize
        @transport = :turbo
        @runtime_assets = :self_hosted
        @library_spec_path = nil
        @prompt_path = nil
        @library_name = :chat
        @actions_endpoint = DEFAULT_ACTIONS_ENDPOINT
        @surface_id_param = :surface_id
        @stream_byte_limit = DEFAULT_STREAM_BYTE_LIMIT
        @pending_byte_limit = DEFAULT_PENDING_BYTE_LIMIT
        @idempotency_ttl = DEFAULT_IDEMPOTENCY_TTL
        @idempotency_store = nil
        @authorize_action = nil
        @on_error = nil
        @action_registry = nil
        @surface_resolver = nil
      end

      def transport=(value)
        value = value.to_sym
        unless TRANSPORTS.include?(value)
          raise ConfigurationError, "unsupported transport #{value.inspect}; expected one of #{TRANSPORTS.inspect}"
        end

        @transport = value
      end

      def runtime_assets=(value)
        value = value.to_sym
        unless ASSET_STRATEGIES.include?(value)
          raise ConfigurationError,
                "unsupported runtime_assets #{value.inspect}; expected one of #{ASSET_STRATEGIES.inspect}"
        end

        @runtime_assets = value
      end

      def idempotency_store=(store)
        unless store.nil? || store.respond_to?(:claim)
          raise ConfigurationError, "idempotency_store must respond to #claim"
        end

        @idempotency_store = store
      end

      def authorize_action=(callable)
        unless callable.nil? || callable.respond_to?(:call)
          raise ConfigurationError, "authorize_action must respond to #call"
        end

        @authorize_action = callable
      end

      def surface_resolver=(callable)
        unless callable.nil? || callable.respond_to?(:call)
          raise ConfigurationError, "surface_resolver must respond to #call"
        end

        @surface_resolver = callable
      end

      # The registry of callable actions. Lazily created so require order does
      # not matter and host apps can replace it if they wish.
      def action_registry
        @action_registry ||= Actions::Registry.new
      end

      # Fingerprint of the pinned library manifest, or nil when unconfigured.
      def library_fingerprint
        library_manifest&.fingerprint
      end

      # Memoized manifest for the configured `library_spec_path`.
      def library_manifest
        return @library_manifest if defined?(@library_manifest) && @library_manifest

        path = library_spec_path
        return nil if path.nil?

        @library_manifest = LibraryManifest.load(path)
      end

      # Drop memoized derived state (used after config changes and in tests).
      def reset!
        remove_instance_variable(:@library_manifest) if defined?(@library_manifest)
        @action_registry = nil
        self
      end

      # Raise when required settings are missing. Called by the engine before
      # the app serves requests so misconfiguration fails fast and visibly.
      def validate!
        raise ConfigurationError, "library_spec_path is not configured" if library_spec_path.nil?

        if pending_byte_limit <= 0 || stream_byte_limit <= 0
          raise ConfigurationError, "stream byte limits must be positive"
        end

        if pending_byte_limit > stream_byte_limit
          raise ConfigurationError, "pending_byte_limit must not exceed stream_byte_limit"
        end

        true
      end
    end

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield configuration
        configuration.reset!
        configuration
      end

      def reset_configuration!
        @configuration = nil
      end

      # Shorthand for the action registry.
      def actions
        configuration.action_registry
      end
    end
  end
end
