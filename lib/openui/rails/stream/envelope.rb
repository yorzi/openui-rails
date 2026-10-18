# frozen_string_literal: true

require "json"

module OpenUI
  module Rails
    module Stream
      # A single, gem-defined stream frame. This is *not* an OpenUI protocol:
      # it is the wire shape the Gem normalizes chunks into over Turbo Streams
      # or Action Cable. Ordering is per message and starts at sequence 0.
      #
      # Payloads never carry tools, credentials or server secrets.
      class Envelope
        DELTA = "openui.delta"
        SNAPSHOT = "openui.snapshot"
        COMPLETED = "openui.completed"
        ERROR = "openui.error"
        TYPES = [ DELTA, SNAPSHOT, COMPLETED, ERROR ].freeze

        MAX_MESSAGE_ID_BYTES = 200
        ERROR_CODES = %w[
          stream_too_large
          stream_failed
          stream_cancelled
          provider_rejected
          library_version_mismatch
          renderer_error
        ].freeze

        attr_reader :message_id, :sequence, :type, :library_version, :data

        def initialize(type:, message_id:, sequence:, library_version: nil, data: {})
          @type = validate_type(type).dup.freeze
          @message_id = validate_message_id(message_id).dup.freeze
          @sequence = validate_sequence(sequence)
          unless library_version.nil? || library_version.is_a?(String)
            raise StreamError, "library_version must be a String"
          end
          @library_version = library_version&.dup&.freeze
          unless data.is_a?(Hash) && (data.keys.map(&:to_s) & %w[type message_id sequence library_version]).empty?
            raise StreamError, "envelope data cannot override routing metadata"
          end
          @data = JsonValue.copy(data)
          validate_data!
          freeze
        end

        class << self
          def delta(message_id:, sequence:, delta:, library_version: nil, streaming: true)
            validate_string!(delta, "delta")
            new(
              type: DELTA, message_id: message_id, sequence: sequence, library_version: library_version,
              data: { "delta" => delta, "streaming" => streaming }
            )
          end

          def snapshot(message_id:, sequence:, response:, library_version: nil, streaming: false)
            validate_string!(response, "response")
            new(
              type: SNAPSHOT, message_id: message_id, sequence: sequence, library_version: library_version,
              data: { "response" => response, "streaming" => streaming }
            )
          end

          def completed(message_id:, sequence:, library_version: nil)
            new(
              type: COMPLETED, message_id: message_id, sequence: sequence, library_version: library_version,
              data: { "streaming" => false }
            )
          end

          def error(message_id:, sequence:, code:, message: nil, library_version: nil)
            code = code.to_s
            unless ERROR_CODES.include?(code)
              raise StreamError, "unknown error code #{code.inspect}; expected one of #{ERROR_CODES.inspect}"
            end

            new(
              type: ERROR, message_id: message_id, sequence: sequence, library_version: library_version,
              data: { "code" => code, "message" => message, "streaming" => false }.compact
            )
          end

          def validate_string!(value, name)
            return if value.is_a?(String)

            raise StreamError, "#{name} must be a String"
          end
        end

        def delta = data["delta"]
        def response = data["response"]
        def code = data["code"]
        def streaming? = data["streaming"] == true
        def delta? = type == DELTA
        def snapshot? = type == SNAPSHOT
        def completed? = type == COMPLETED
        def error? = type == ERROR

        def to_h
          hash = { "message_id" => message_id, "sequence" => sequence, "type" => type }
          hash["library_version"] = library_version if library_version
          hash.merge!(data)
          hash
        end

        def to_json(*) = JSON.generate(to_h)

        def ==(other)
          other.is_a?(Envelope) && other.to_h == to_h
        end
        alias eql? ==

        def hash = to_h.hash

        private

        def validate_data!
          case type
          when DELTA then self.class.validate_string!(delta, "delta")
          when SNAPSHOT then self.class.validate_string!(response, "response")
          when ERROR
            raise StreamError, "unknown error code #{code.inspect}" unless ERROR_CODES.include?(code)
          end
          if data.key?("streaming") && ![ true, false ].include?(data["streaming"])
            raise StreamError, "streaming must be boolean"
          end
        end

        def validate_type(type)
          type = type.to_s
          raise StreamError, "unknown envelope type #{type.inspect}" unless TYPES.include?(type)

          type
        end

        def validate_message_id(message_id)
          unless message_id.is_a?(String) && !message_id.empty?
            raise StreamError, "message_id must be a non-empty String"
          end

          if message_id.bytesize > MAX_MESSAGE_ID_BYTES
            raise StreamError, "message_id exceeds #{MAX_MESSAGE_ID_BYTES} bytes"
          end

          message_id
        end

        def validate_sequence(sequence)
          unless sequence.is_a?(Integer) && sequence >= 0
            raise StreamError, "sequence must be a non-negative Integer"
          end

          sequence
        end
      end
    end
  end
end
