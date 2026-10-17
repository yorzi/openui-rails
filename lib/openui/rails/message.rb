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
          text = stored.to_s
          return empty_parse(text) unless marker_present?(text)

          lines = normalized_lines(text)
          lines = drop_partial_marker(lines) if streaming && !text.end_with?("\n")
          assemble(lines)
        end

        # Strip the markers for model history; returns only the content body.
        def strip(stored)
          parse(stored).content
        end

        private

        def empty_parse(text)
          Parsed.new(content: text, context: nil, attributes: {}, finished: false)
        end

        def content_marker(attributes)
          return CONTENT_MARKER if attributes.nil? || attributes.empty?

          "#{CONTENT_MARKER}?#{URI.encode_www_form(attributes)}"
        end

        def marker_present?(text)
          text.include?(CONTENT_MARKER) ||
            text.split("\n").any? { |line| line.start_with?(MARKER_PREFIX) }
        end

        # A content marker that appears mid-line is moved onto its own line
        # first; the other markers only count at the start of a line.
        def normalized_lines(text)
          text.gsub(/(?<=[^\n])#{Regexp.escape(CONTENT_MARKER)}/, "\n#{CONTENT_MARKER}").split("\n", -1)
        end

        def drop_partial_marker(lines)
          last = lines.last
          return lines unless last && MARKERS.any? { |marker| marker.start_with?(last) }

          lines[0..-2]
        end

        def assemble(lines)
          state = { section: nil, content: [], context: nil, attributes: {}, content_seen: false, finished: false }
          preamble = []
          lines.each do |line|
            if line.start_with?(MARKER_PREFIX)
              handle_marker(state, line)
            else
              append_line(state, preamble, line)
            end
          end

          content = state[:content_seen] ? state[:content].join("\n") : preamble.join("\n")

          Parsed.new(
            content: content,
            context: state[:context],
            attributes: state[:attributes],
            finished: state[:finished]
          )
        end

        def handle_marker(state, line)
          kind, _, query = line.delete_prefix(MARKER_PREFIX).partition("?")

          case kind
          when "content"
            state[:content_seen] = true
            state[:content] = []
            state[:context] = nil
            state[:attributes] = decode_attributes(query)
            state[:section] = :content
          when "context"
            state[:section] = :context
          when "end"
            state[:finished] = true
            state[:section] = :ignored
          else
            state[:section] = :ignored
          end
        end

        def append_line(state, preamble, line)
          case state[:section]
          when :content then state[:content] << line
          when :context then append_context(state, line)
          when :ignored then nil
          else preamble << line
          end
        end

        def append_context(state, line)
          body = [ state[:context].is_a?(String) ? state[:context] : nil, line ].compact.join("\n")
          state[:context] = parse_context(body)
        end

        def parse_context(body)
          JSON.parse(body)
        rescue JSON::ParserError
          body
        end

        def decode_attributes(query)
          return {} if query.nil? || query.empty?

          URI.decode_www_form(query).to_h
        rescue ArgumentError
          {}
        end
      end
    end
  end
end
