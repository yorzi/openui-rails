# frozen_string_literal: true

module OpenUI
  module Rails
    # Immutable description of one mounted OpenUI surface.
    #
    # The host Rails app owns persistence; the Gem only needs a stable,
    # opaque identifier plus the current revision and the source to render.
    # A surface can be built explicitly or coerced from a host record that
    # exposes `id` (and, optionally, `version`, `library_version`, `response`,
    # `context`, `message_id`).
    class Surface
      ATTRIBUTES = %i[id version library_version response context streaming message_id].freeze

      attr_reader(*ATTRIBUTES)

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

      def initialize(id:, version: 0, library_version: nil, response: nil, context: nil,
                     streaming: false, message_id: nil)
        raise ArgumentError, "surface id is required" if id.nil? || id.to_s.empty?
        unless version.nil? || (version.is_a?(Integer) && version >= 0)
          raise ArgumentError, "surface version must be a non-negative Integer"
        end
        raise ArgumentError, "surface response must be a String" unless response.nil? || response.is_a?(String)

        @id = id.to_s.dup.freeze
        @version = version || 0
        @library_version = library_version&.to_s&.dup&.freeze
        @response = response&.dup&.freeze
        @context = JsonValue.copy(context)
        @streaming = streaming ? true : false
        @message_id = (message_id&.to_s || @id).dup.freeze
        freeze
      end

      def streaming? = @streaming

      def to_h
        {
          id: id, version: version, library_version: library_version,
          response: response, context: context, streaming: streaming, message_id: message_id
        }
      end

      # The flat `data:` hash for the Stimulus mount element. Keys use
      # underscores so Rails renders them as `data-openui-*` attributes; nil
      # values are omitted so the controller can rely on presence.
      #
      # Every value is deliberately a String. DOM data attributes are strings,
      # and Rails only JSON-coerces *non-String* values — a path that broke on
      # Rails 8.0 with json >= 3.1 (ActiveSupport passes a `quirks_mode:`
      # keyword the gem removed). Emitting strings keeps rendering independent
      # of ActiveSupport's JSON encoder.
      def to_mount_data(stream: false, actions_endpoint:, initial_state: nil)
        {
          controller: "openui",
          openui_surface_id: id,
          openui_message_id: message_id,
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
