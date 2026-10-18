# frozen_string_literal: true

require "json"
require "uri"

module OpenUI
  module Rails
    # Ruby implementation of the upstream OpenUI message protocol (`buildMessage`
    # / `parseMessage` from `@openuidev/react-lang` and `@openuidev/lang-core`).
    #
    # A stored message is the response text wrapped in marker lines that start
    # with `]]>openui:`. The browser `Renderer` reads the whole stored message
    # and ignores the context; the host app is responsible for restoring form
    # state from the context as `initialState`. Markers must never reach the
    # model: strip them with {.strip} (i.e. `parseMessage(content)`).
    #
    # This is *message framing*, not an OpenUI Lang parser.
    module Message
      CONTENT_MARKER = "]]>openui:content"
      CONTEXT_MARKER = "]]>openui:context"
      END_MARKER = "]]>openui:end"
      MARKERS = [ CONTENT_MARKER, CONTEXT_MARKER, END_MARKER ].freeze
      MARKER_PREFIX = "]]>openui:"

      # Result of {.parse}. `finished` maps to the upstream `end` field.
      Parsed = Struct.new(:content, :context, :attributes, :finished, keyword_init: true) do
        def finished? = finished

        def to_h
          { content: content, context: context, attributes: attributes, end: finished }
        end
      end

      class << self
        # Wrap content (and optional context/attributes) in the marker format.
        #
        # @param content [String] the response text (OpenUI Lang or prose)
        # @param context [String, Object, nil] stored context; strings verbatim,
        #   anything else JSON-encoded, nil writes no context section
        # @param attributes [Hash, nil] written after `?`, URLSearchParams-encoded
        # @param finished [Boolean] add the `end` line (accepts the upstream
        #   `end:` keyword too)
        # @return [String]
        def build(content:, context: nil, attributes: nil, finished: false, **options)
          finished = options.fetch(:end, finished) if options.key?(:end)
          raise ArgumentError, "unknown options: #{options.keys.inspect}" unless (options.keys - [ :end ]).empty?

          lines = [ content_marker(attributes), content.to_s ]
          unless context.nil?
            lines << CONTEXT_MARKER
            lines << (context.is_a?(String) ? context : JSON.generate(context))
          end
          lines << END_MARKER if finished
          lines.join("\n")
        end

        # Parse a stored message into its parts.
        #
        # @param stored [String]
        # @param streaming [Boolean] hold back a trailing partial marker line
        # @return [Parsed]
        def parse(stored, streaming: false)
          # Match lang-core 1.0.1 framing, including retries, CRLF boundaries
          # and incomplete streaming markers. This is not a DSL parser.
          text = stored.to_s.gsub(/([^\n])(?=\]\]>openui:content(?:\?|\r?\n|\z))/, "\\1\n")
          if streaming && (cut = /[^\n](\]\]>[a-z:]*)\z/.match(text)) && CONTENT_MARKER.start_with?(cut[1])
            text = text[0..cut.begin(0)]
          end
          lines = text.split("\n", -1)
          last = lines.last
          held = streaming && last && !last.empty? && (last.start_with?(MARKER_PREFIX) || MARKER_PREFIX.start_with?(last))
          lines.pop if held
          sections = [ { kind: nil, attributes: {}, lines: [] } ]
          end_at = -1
          lines.each_with_index do |line, index|
            match = /\A\]\]>openui:([a-z]+)(?:\?(.*))?\z/.match(line.delete_suffix("\r"))
            unless match
              sections.last[:lines] << line
              next
            end
            close_section(sections.last)
            if match[1] == "end"
              end_at = sections.size - 1
              break if index == lines.size - 2 && lines.last == ""
            else
              sections << { kind: match[1], attributes: decode_attributes(match[2]), lines: [] }
            end
          end
          close_section(sections.last) if held
          winner = sections.rindex { |section| section[:kind] == "content" } || 0
          context_index = sections.rindex { |section| section[:kind] == "context" }
          context = parse_context(sections[context_index][:lines].join("\n")) if context_index && context_index > winner
          Parsed.new(content: sections[winner][:lines].join("\n"), context: context,
            attributes: sections[winner][:attributes], finished: end_at >= winner)
        end

        # Strip the markers for model history; returns only the content body.
        def strip(stored)
          parse(stored).content
        end

        private

        def content_marker(attributes)
          return CONTENT_MARKER if attributes.nil? || attributes.empty?

          "#{CONTENT_MARKER}?#{URI.encode_www_form(attributes)}"
        end

        def close_section(section)
          section[:lines][-1] = section[:lines].last.delete_suffix("\r") unless section[:lines].empty?
        end

        def parse_context(body)
          JSON.parse(body)
        rescue JSON::ParserError
          body
        end

        def decode_attributes(query)
          return {} if query.nil? || query.empty?

          query.split("&").each_with_object({}) do |pair, attributes|
            key, _, value = pair.partition("=")
            key = decode_attribute(key)
            attributes[key] = decode_attribute(value) unless key.empty?
          end
        end

        def decode_attribute(value)
          decoded = URI.decode_www_form_component(value)
          decoded.valid_encoding? ? decoded : value
        rescue ArgumentError
          value
        end
      end
    end
  end
end
