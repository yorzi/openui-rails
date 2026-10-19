# frozen_string_literal: true

module OpenUI
  module Rails
    # Immutable description of one mounted OpenUI surface.
    #
    # The host Rails app owns persistence; the Gem only needs a stable,
    # opaque identifier plus the current revision and the source to render.
    # A surface can be built explicitly or coerced from a host record that
    # exposes `id` (and, optionally, `version`, `library_version`, `response`,
    # `context`, `message_id`, `next_sequence`, `completed`).
    class Surface
      # Surface values copied from an explicit object, hash, or host record.
      ATTRIBUTES = %i[id version library_version response context streaming message_id next_sequence completed].freeze

      attr_reader(*ATTRIBUTES)

      # Coerce a host record, hash, or existing surface into a new Surface.
      # Non-nil overrides replace values extracted from the input.
      #
      # @param value [Surface, Hash, #id, nil]
      #
      # @param overrides [Hash] surface attribute overrides
      #
      # @return [Surface]
      def self.coerce(value = nil, **overrides)
        attributes = extract(value).merge(overrides.compact)
        new(**attributes)
      end

      def self.extract(value)
        case value
        when nil then {}
        when Surface then value.to_h
        when Hash
          ATTRIBUTES.each_with_object({}) do |key, attributes|
            if value.key?(key)
              attributes[key] = value[key]
            elsif value.key?(key.to_s)
              attributes[key] = value[key.to_s]
            end
          end
        else extract_record(value)
        end
      end
      private_class_method :extract

      def self.extract_record(record)
        unless record.respond_to?(:id)
          raise ArgumentError, "surface must respond to #id or be a Hash/#{name}"
        end

        ATTRIBUTES.each_with_object({ id: record.id }) do |attribute, memo|
          memo[attribute] = record.public_send(attribute) if attribute != :id && record.respond_to?(attribute)
        end
      end
      private_class_method :extract_record

      # Build an immutable surface snapshot for the browser mount.
      #
      # @param id [String, #to_s] stable opaque identifier
      #
      # @param version [Integer, nil] non-negative revision used for stale-action checks
      #
      # @param library_version [String, nil] fingerprint of the browser library manifest
      #
      # @param response [String, nil] OpenUI Lang source rendered by the browser
      #
      # @param context [Object, nil] JSON-compatible initial state
      #
      # @param streaming [Boolean] whether a response is still streaming
      #
      # @param message_id [String, nil] stream identity; defaults to id
      #
      # @param next_sequence [Integer] next expected envelope sequence after persisted output
      #
      # @param completed [Boolean] ignore later non-snapshot envelopes for a terminal response
      #
      # @return [Surface]
      def initialize(id:, version: 0, library_version: nil, response: nil, context: nil,
                     streaming: false, message_id: nil, next_sequence: 0, completed: false)
        raise ArgumentError, "surface id is required" if id.nil? || id.to_s.empty?
        unless version.nil? || (version.is_a?(Integer) && version >= 0)
          raise ArgumentError, "surface version must be a non-negative Integer"
        end
        raise ArgumentError, "surface response must be a String" unless response.nil? || response.is_a?(String)

        unless next_sequence.is_a?(Integer) && next_sequence.between?(0, 9_007_199_254_740_991)
          raise ArgumentError, "next_sequence must be a non-negative JavaScript-safe Integer"
        end
        unless [ true, false ].include?(completed) && !(completed && streaming)
          raise ArgumentError, "completed must be boolean and cannot coexist with streaming"
        end

        @next_sequence = next_sequence
        @completed = completed
        @id = id.to_s.dup.freeze
        @version = version || 0
        @library_version = library_version&.to_s&.dup&.freeze
        @response = response&.dup&.freeze
        @context = JsonValue.copy(context)
        @streaming = streaming ? true : false
        @message_id = (message_id&.to_s || @id).dup.freeze
        freeze
      end

      # Whether the host says this surface is still receiving a response.
      #
      # @return [Boolean]
      def streaming? = @streaming

      # Return the surface fields as a symbol-keyed hash.
      #
      # @return [Hash]
      def to_h
        {
          id: id, version: version, library_version: library_version,
          response: response, context: context, streaming: streaming, message_id: message_id,
          next_sequence: next_sequence, completed: completed
        }
      end

      # The flat `data:` hash for the Stimulus mount element. Keys use
      # underscores so Rails renders them as `data-openui-*` attributes; nil
      # values are omitted so the controller can rely on presence.
      #
      # Every value is deliberately a String. DOM data attributes are strings,
      # and Rails only JSON-coerces *non-String* values. This path broke on
      # Rails 8.0 with json >= 3.1 (ActiveSupport passes a `quirks_mode:`
      # keyword the gem removed). Emitting strings keeps rendering independent
      # of ActiveSupport's JSON encoder.
      #
      # @param stream [Boolean] mark this mount as streaming
      #
      # @param actions_endpoint [String] host engine action URL
      #
      # @param initial_state [Object, nil] JSON-compatible state override
      #
      # @return [Hash] HTML data attributes with string values
      def to_mount_data(stream: false, actions_endpoint:, initial_state: nil)
        raise ArgumentError, "completed surfaces cannot be mounted as streaming" if completed && stream

        {
          controller: "openui",
          openui_surface_id: id,
          openui_message_id: message_id,
          openui_next_sequence: next_sequence.to_s,
          openui_completed: completed.to_s,
          openui_version: version.to_s,
          openui_library_version: library_version,
          openui_streaming: (streaming? || stream) ? "true" : "false",
          openui_actions_url: actions_endpoint,
          openui_response: response,
          openui_stream_byte_limit: OpenUI::Rails.configuration.stream_byte_limit.to_s,
          openui_initial_state: encode_state(initial_state || context)
        }.compact
      end

      private

      def encode_state(state)
        return nil if state.nil?

        state.is_a?(String) ? state : JSON.generate(state)
      end
    end
  end
end
