# frozen_string_literal: true

module OpenUI
  module Rails
    module Actions
      # Validates the `args` of an action submission against a small, explicit
      # contract. It is intentionally not a general-purpose schema language: it
      # only ensures the shape a host handler relies on, so a malformed payload
      # is rejected before any side effect.
      class Schema
        # Wraps a host predicate. Returning false (or raising) rejects the args.
        class Callable
          def initialize(callable)
            @callable = callable
          end

          def validate!(args)
            raise InvalidActionError, "action arguments must be an object" unless args.is_a?(Hash)
            raise InvalidActionError, "action arguments failed validation" unless @callable.call(args)

            args
          end
        end

        # A schema that accepts any JSON object.
        def self.any
          new(required: {}, optional: {}, allow_extra: true)
        end

        def self.define(required: {}, optional: {}, allow_extra: false)
          new(required: required || {}, optional: optional || {}, allow_extra: allow_extra)
        end

        # Build a schema from a Hash of required types, an existing Schema or a
        # callable predicate.
        def self.from(value)
          case value
          when nil then any
          when Schema, Callable then value
          when Hash then new(required: value, allow_extra: false)
          else
            unless value.respond_to?(:call)
              raise ConfigurationError, "schema must be a Hash, Schema, or respond to #call"
            end

            Callable.new(value)
          end
        end

        attr_reader :required, :optional

        def initialize(required: {}, optional: {}, allow_extra: false)
          @required = required
          @optional = optional
          @allow_extra = allow_extra
        end

        def allow_extra? = @allow_extra

        def validate!(args)
          raise InvalidActionError, "action arguments must be an object" unless args.is_a?(Hash)

          values = normalize(args)
          validate_required(values)
          validate_optional(values)
          validate_extras(values.keys) unless allow_extra?
          args
        end

        private

        def normalize(args)
          args.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }
        end

        def validate_required(values)
          required.each do |key, expected|
            name = key.to_s
            raise InvalidActionError, "missing required argument #{name}" unless values.key?(name)
            next if type_matches?(values[name], expected)

            raise InvalidActionError, "argument #{name} has an invalid value"
          end
        end

        def validate_optional(values)
          optional.each do |key, expected|
            name = key.to_s
            next unless values.key?(name)
            next if type_matches?(values[name], expected)

            raise InvalidActionError, "argument #{name} has an invalid value"
          end
        end

        def validate_extras(keys)
          allowed = (required.keys + optional.keys).map(&:to_s)
          extra = keys - allowed
          return if extra.empty?

          raise InvalidActionError, "unexpected arguments: #{extra.join(", ")}"
        end

        def type_matches?(value, expected)
          case expected
          when Array then expected.any? { |candidate| type_matches?(value, candidate) }
          when Regexp then value.is_a?(String) && expected.match?(value)
          when Module then value.is_a?(expected)
          else expected.respond_to?(:call) ? expected.call(value) == true : false
          end
        end
      end
    end
  end
end
