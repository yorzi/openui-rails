# frozen_string_literal: true

require "digest"
require "json"

module OpenUI
  module Rails
    module Actions
      # Validated, immutable view of the payload emitted by a component
      # `onAction` or a browser `toolProvider` `Query()`/`Mutation()` call:
      #
      #   { action:, args:, surface_id:, version:, idempotency_key: }
      #
      # `confirmed` is the Gem's explicit-confirmation flag for destructive
      # actions. Unknown keys are ignored; known keys are validated strictly.
      class Submission
        MAX_IDEMPOTENCY_KEY_BYTES = 200

        attr_reader :action, :args, :surface_id, :version, :idempotency_key, :confirmed

        def self.parse(payload)
          return payload if payload.is_a?(Submission)

          raise InvalidActionError, "action payload must be an object" unless payload.is_a?(Hash)

          values = payload.each_with_object({}) { |(key, value), memo| memo[key.to_s] = value }

          new(
            action: values["action"],
            args: values.fetch("args", {}),
            surface_id: values["surface_id"] || values["surfaceId"],
            version: values["version"],
            idempotency_key: values["idempotency_key"] || values["idempotencyKey"],
            confirmed: values["confirmed"] == true
          )
        end

        def initialize(action:, surface_id:, version:, idempotency_key:, args: {}, confirmed: false)
          @action = validate_string(action, "action")
          @surface_id = validate_string(surface_id, "surface_id")
          @idempotency_key = validate_idempotency_key(idempotency_key)
          @version = validate_version(version)
          @args = validate_args(args)
          @confirmed = confirmed == true
          @args_digest = Digest::SHA256.hexdigest(JSON.generate(@args)).freeze
          freeze
        end

        def confirmed? = confirmed

        # Stable digest of the args, used for idempotency conflict detection.
        attr_reader :args_digest

        def to_h
          {
            action: action,
            args: args,
            surface_id: surface_id,
            version: version,
            idempotency_key: idempotency_key,
            confirmed: confirmed
          }
        end

        private

        def validate_string(value, name)
          string = value.to_s
          raise InvalidActionError, "#{name} is required" if string.empty?
          raise InvalidActionError, "#{name} must be a scalar" unless value.is_a?(String) || value.is_a?(Symbol)

          string.dup.freeze
        end

        def validate_idempotency_key(value)
          key = validate_string(value, "idempotency_key")
          if key.bytesize > MAX_IDEMPOTENCY_KEY_BYTES
            raise InvalidActionError, "idempotency_key exceeds #{MAX_IDEMPOTENCY_KEY_BYTES} bytes"
          end

          key
        end

        def validate_version(value)
          unless value.is_a?(Integer) && value >= 0
            raise InvalidActionError, "version must be a non-negative Integer"
          end

          value
        end

        def validate_args(value)
          raise InvalidActionError, "args must be an object" unless value.is_a?(Hash)

          JsonValue.copy(value)
        rescue ArgumentError => error
          raise InvalidActionError, error.message
        end
      end
    end
  end
end
