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
      # Transport names accepted by the host preference setting.
      TRANSPORTS = %i[turbo action_cable none].freeze

      # Runtime asset strategies supported by the gem.
      ASSET_STRATEGIES = %i[self_hosted external].freeze

      # Maximum response size passed through the stream bridge, in bytes.
      DEFAULT_STREAM_BYTE_LIMIT = 1_048_576 # 1 MiB of OpenUI Lang per message

      # Buffer size before the bridge emits a delta, in bytes.
      DEFAULT_PENDING_BYTE_LIMIT = 32_768   # flush threshold while streaming

      # Lifetime of an action idempotency claim, in seconds.
      DEFAULT_IDEMPOTENCY_TTL = 15 * 60     # seconds

      # Default engine endpoint for action submissions.
      DEFAULT_ACTIONS_ENDPOINT = "/openui-rails/actions"

      attr_reader :transport, :runtime_assets
      attr_accessor :library_spec_path, :prompt_path, :library_name,
                    :actions_endpoint, :surface_id_param,
                    :stream_byte_limit, :pending_byte_limit, :idempotency_ttl,
                    :authorize_action, :on_error, :action_registry, :surface_resolver, :actor_resolver,
                    :runtime_version, :runtime_url, :runtime_integrity, :local_runtime_path,
                    :idempotency_scope, :runtime_stylesheet_url, :runtime_stylesheet_integrity

      # Create the default integration settings.
      #
      # @return [Configuration]
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
        @actor_resolver = nil
        @runtime_version = nil
        @runtime_url = nil
        @runtime_integrity = nil
        @local_runtime_path = "/openui"
      end

      # Set the preferred host stream transport.
      #
      # @param value [Symbol] `:turbo`, `:action_cable`, or `:none`
      #
      # @return [Symbol]
      def transport=(value)
        value = value.to_sym if value.respond_to?(:to_sym)
        unless TRANSPORTS.include?(value)
          raise ConfigurationError, "unsupported transport #{value.inspect}; expected one of #{TRANSPORTS.inspect}"
        end

        @transport = value
      end

      # Choose self-hosted or externally served runtime assets.
      #
      # @param value [Symbol] `:self_hosted` or `:external`
      #
      # @return [Symbol]
      def runtime_assets=(value)
        value = value.to_sym if value.respond_to?(:to_sym)
        unless ASSET_STRATEGIES.include?(value)
          raise ConfigurationError,
                "unsupported runtime_assets #{value.inspect}; expected one of #{ASSET_STRATEGIES.inspect}"
        end

        @runtime_assets = value
      end

      # Set the store used to claim and record action idempotency keys.
      # A shared store must implement the atomic contract described in the
      # configuration guide.
      #
      # @param store [#claim, #record, nil]
      #
      # @return [#claim, #record]
      def idempotency_store=(store)
        unless store.nil? || (store.respond_to?(:claim) && store.respond_to?(:record))
          raise ConfigurationError, "idempotency_store must respond to #claim and #record"
        end

        @idempotency_store = store
      end

      # Set the manifest path and clear the cached manifest.
      #
      # @param path [String, Pathname, nil]
      #
      # @return [String, Pathname, nil]
      def library_spec_path=(path)
        @library_spec_path = path
        reset!
      end

      # Set a callable that returns a stable actor and tenant idempotency scope.
      #
      # @param callable [#call, nil] receives an Actions::Invocation
      #
      # @return [#call, nil]
      def idempotency_scope=(callable)
        unless callable.nil? || callable.respond_to?(:call)
          raise ConfigurationError, "idempotency_scope must respond to #call"
        end

        @idempotency_scope = callable
      end

      # Set the global authorizer used when an action has no local authorizer.
      #
      # @param callable [#call, nil] receives an Actions::Invocation
      #
      # @return [#call, nil]
      def authorize_action=(callable)
        unless callable.nil? || callable.respond_to?(:call)
          raise ConfigurationError, "authorize_action must respond to #call"
        end

        @authorize_action = callable
      end

      # Set the resolver that loads a surface inside the actor's permitted scope.
      #
      # @param callable [#call, nil] receives surface_id, actor, and context
      #
      # @return [#call, nil]
      def surface_resolver=(callable)
        unless callable.nil? || callable.respond_to?(:call)
          raise ConfigurationError, "surface_resolver must respond to #call"
        end

        @surface_resolver = callable
      end

      # Set the callable that resolves the current actor from the engine controller.
      #
      # @param callable [#call, nil] receives the engine controller
      #
      # @return [#call, nil]
      def actor_resolver=(callable)
        unless callable.nil? || callable.respond_to?(:call)
          raise ConfigurationError, "actor_resolver must respond to #call"
        end

        @actor_resolver = callable
      end

      # Return the configured store, creating a process-local memory store by default.
      #
      # @return [#claim, #record]
      def idempotency_store
        @idempotency_store ||= Actions::Idempotency::MemoryStore.new
      end

      # The registry of callable actions. Lazily created so require order does
      # not matter and host apps can replace it if they wish.
      #
      # @return [Actions::Registry]
      def action_registry
        @action_registry ||= Actions::Registry.new
      end

      # Fingerprint of the pinned library manifest, or nil when unconfigured.
      #
      # @return [String, nil]
      def library_fingerprint
        library_manifest&.fingerprint
      end

      # Memoized manifest for the configured `library_spec_path`.
      #
      # @return [LibraryManifest, nil]
      def library_manifest
        return @library_manifest if defined?(@library_manifest) && @library_manifest

        path = library_spec_path
        return nil if path.nil?

        @library_manifest = LibraryManifest.load(path)
      end

      # Drop memoized derived state (used after config changes and in tests).
      # The action registry and idempotency store are runtime state and are
      # preserved so re-configuring does not silently unregister actions.
      #
      # @return [self]
      def reset!
        remove_instance_variable(:@library_manifest) if defined?(@library_manifest)
        self
      end

      # Explicit host readiness check. Not run during boot: the generator and
      # runtime-fetch task must work before library files have been created.
      #
      # @return [true]
      #
      # @raise [ConfigurationError, ManifestError] when required settings or files are invalid
      def validate!
        raise ConfigurationError, "library_spec_path is not configured" if library_spec_path.nil?

        if runtime_assets == :external && (runtime_url.nil? || runtime_url.empty?)
          raise ConfigurationError, "runtime_assets :external requires an explicit, version-pinned runtime_url"
        end

        unless pending_byte_limit.is_a?(Integer) && stream_byte_limit.is_a?(Integer) &&
            pending_byte_limit > 0 && stream_byte_limit > 0
          raise ConfigurationError, "stream byte limits must be positive"
        end

        if pending_byte_limit > stream_byte_limit
          raise ConfigurationError, "pending_byte_limit must not exceed stream_byte_limit"
        end

        unless idempotency_ttl.is_a?(Numeric) && idempotency_ttl.finite? && idempotency_ttl > 0
          raise ConfigurationError, "idempotency_ttl must be positive"
        end

        reset!
        library_manifest
        PromptBuilder.load(self) if prompt_path
        true
      end
    end

    class << self
      # Return the process-wide OpenUI Rails configuration.
      #
      # @return [Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # Configure the process-wide integration and clear derived manifest state.
      #
      # @yieldparam config [Configuration]
      #
      # @return [Configuration]
      def configure
        yield configuration
        configuration.reset!
        configuration
      end

      # Discard the current configuration object. Primarily useful in tests.
      #
      # @return [nil]
      def reset_configuration!
        @configuration = nil
      end

      # Shorthand for the action registry.
      #
      # @return [Actions::Registry]
      def actions
        configuration.action_registry
      end
    end
  end
end
