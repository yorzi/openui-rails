# frozen_string_literal: true

module OpenUI
  module Rails
    module Actions
      # The allowlist of actions a model-generated surface may invoke. Only
      # handlers registered here are reachable: there is no reflection from a
      # model-provided name to a Ruby method.
      class Registry
        # Immutable definition stored by the registry and passed to dispatch.
        Definition = Struct.new(:name, :handler, :authorize, :schema, :confirmation, :description, keyword_init: true)

        # Pattern accepted for action names sent over the wire.
        NAME_PATTERN = /\A[a-zA-Z][a-zA-Z0-9_.:-]{0,63}\z/

        # Create an empty action allowlist.
        #
        # @return [Registry]
        def initialize
          @definitions = {}
          @mutex = Mutex.new
        end

        # Register a callable action.
        #
        # @param name [String, Symbol] the wire name the surface emits
        #
        # @param handler [#call] receives an Invocation, performs the work
        #
        # @param authorize [#call, nil] receives an Invocation, returns truthy
        #   when allowed. Required at dispatch time (fail closed).
        #
        # @param schema [Schema, Hash, #call, nil] arg validation
        #
        # @param confirmation [Boolean] require `confirmed: true` on the payload
        #
        # @param description [String, nil] text describing the action
        #
        # @return [Definition]
        def register(name, handler: nil, authorize: nil, schema: nil, confirmation: false, description: nil, &block)
          handler ||= block
          raise ConfigurationError, "handler is required for action #{name.inspect}" unless handler.respond_to?(:call)
          unless authorize.nil? || authorize.respond_to?(:call)
            raise ConfigurationError, "authorize must respond to #call"
          end

          definition = Definition.new(
            name: normalize_name(name).dup.freeze,
            handler: handler,
            authorize: authorize,
            schema: Schema.from(schema),
            confirmation: confirmation ? true : false,
            description: description
          ).freeze

          @mutex.synchronize { @definitions[definition.name] = definition }
          definition
        end

        # Find a registered action or raise when it is not allowlisted.
        #
        # @param name [String, Symbol]
        #
        # @return [Definition]
        #
        # @raise [UnknownActionError] when no action has this name
        def fetch(name)
          definition = @mutex.synchronize { @definitions[normalize_name(name)] }
          raise UnknownActionError, "unknown action #{name.inspect}" if definition.nil?

          definition
        rescue ConfigurationError => error
          raise InvalidActionError, error.message
        end

        # Whether an action name is present in the allowlist.
        #
        # @param name [String, Symbol]
        #
        # @return [Boolean]
        def registered?(name)
          @mutex.synchronize { @definitions.key?(normalize_name(name)) }
        end

        # Return the registered action names.
        #
        # @return [Array<String>]
        def names
          @mutex.synchronize { @definitions.keys }
        end

        # Remove all registered actions.
        #
        # @return [self]
        def clear!
          @mutex.synchronize { @definitions.clear }
          self
        end

        private

        def normalize_name(name)
          name = name.to_s
          unless name.match?(NAME_PATTERN)
            raise ConfigurationError, "invalid action name #{name.inspect}"
          end

          name
        end
      end
    end
  end
end
