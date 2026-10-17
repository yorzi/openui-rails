# frozen_string_literal: true

module OpenUI
  module Rails
    module Stream
      # Turns an ordered source of model chunks into an ordered sequence of
      # {Envelope}s, coalescing small chunks up to `pending_byte_limit` and
      # enforcing `stream_byte_limit`. Transport-agnostic: a caller broadcasts
      # the yielded envelopes over Turbo Streams or Action Cable.
      #
      # Failures are surfaced as structured error envelopes with no raw prompt
      # or PII (the host can observe them through `config.on_error`).
      class Bridge
        attr_reader :message_id, :library_version

        def initialize(message_id:, library_version: nil, configuration: OpenUI::Rails.configuration)
          @message_id = message_id
          @library_version = library_version
          @pending_byte_limit = configuration.pending_byte_limit
          @stream_byte_limit = configuration.stream_byte_limit
          @on_error = configuration.on_error
        end

        # @param source [#each] yields String chunks
        # @return [Enumerator<Envelope>]
        def envelopes(source)
          to_enum(:each_envelope, source)
        end

        def each_envelope(source)
          sequence = 0
          total_bytes = 0
          pending = +""

          source.each do |chunk|
            next if chunk.nil? || chunk.empty?

            total_bytes += chunk.bytesize
            if total_bytes > @stream_byte_limit
              yield Envelope.error(
                message_id: message_id, sequence: sequence, library_version: library_version,
                code: "stream_too_large",
                message: "stream exceeded #{@stream_byte_limit} bytes"
              )
              return
            end

            pending << chunk
            next if pending.bytesize < @pending_byte_limit

            yield Envelope.delta(
              message_id: message_id, sequence: sequence, delta: pending.dup,
              library_version: library_version, streaming: true
            )
            sequence += 1
            pending = +""
          end

          unless pending.empty?
            yield Envelope.delta(
              message_id: message_id, sequence: sequence, delta: pending.dup,
              library_version: library_version, streaming: true
            )
            sequence += 1
          end

          yield Envelope.completed(message_id: message_id, sequence: sequence, library_version: library_version)
        rescue OpenUI::Rails::Error => e
          @on_error&.call(e, message_id: message_id)
          yield error_envelope(sequence, "stream_failed", e)
        rescue StandardError => e
          @on_error&.call(e, message_id: message_id)
          yield error_envelope(sequence, "stream_failed", e)
        end

        private

        def error_envelope(sequence, code, error)
          Envelope.error(
            message_id: message_id, sequence: sequence, library_version: library_version,
            code: code, message: "stream failed (#{error.class})"
          )
        end
      end
    end
  end
end
