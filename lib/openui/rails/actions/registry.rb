# frozen_string_literal: true

module OpenUI
  module Rails
    module Actions
      # The allowlist of actions a model-generated surface may invoke. Only
      # handlers registered here are reachable: there is no reflection from a
      # model-provided name to a Ruby method.
      class Registry
        Definition = Struct.new(:name, :handler, :authorize, :schema, :confirmation, :description, keyword_init: true)

        NAME_PATTERN = /\A[a-zA-Z][a-zA-Z0-9_.:-]{0,63}\z/

        def initialize
          @definitions = {}
          @mutex = Mutex.new
        end

        # Register a callable action.
        #
        # @param name [String, Symbol] the wire name the surface emits
        # @param handler [#call] receives an Invocation, performs the work
        # @param authorize [#call, nil] receives an Invocation, returns truthy
        #   when allowed. Required at dispatch time (fail closed).
        # @param schema [Schema, Hash, #call, nil] arg validation
        # @param confirmation [Boolean] require `confirmed: true` on the payload
        def register(name, handler: nil, authorize: nil, schema: nil, confirmation: false, description: nil, &block)
          handler ||= block
          raise ConfigurationError, "handler is required for action #{name.inspect}" unless handler.respond_to?(:call)
          unless authorize.nil? || authorize.respond_to?(:call)
            raise ConfigurationError, "authorize must respond to #call"
          end

          definition = Definition.new(
            name: normalize_name(name),
            handler: handler,
            authorize: authorize,
            schema: Schema.from(schema),
            confirmation: confirmation ? true : false,
            description: description
          ).freeze

          @mutex.synchronize { @definitions[definition.name] = definition }
          definition
        end

        def fetch(name)
          definition = @mutex.synchronize { @definitions[normalize_name(name)] }
          raise UnknownActionError, "unknown action #{name.inspect}" if definition.nil?

          definition
        rescue ConfigurationError => error
          raise InvalidActionError, error.message
        end

        def registered?(name)
          @mutex.synchronize { @definitions.key?(normalize_name(name)) }
        end

        def names
          @mutex.synchronize { @definitions.keys }
        end

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
