# frozen_string_literal: true

module OpenUI
  module Rails
    module Stream
      # Turns model output into an ordered sequence of {Envelope}s, coalescing
      # small chunks up to `pending_byte_limit` and enforcing `stream_byte_limit`.
      # Transport-agnostic: a caller broadcasts the yielded envelopes over Turbo
      # Streams or Action Cable.
      #
      # Pull sources (an Enumerable of chunks) go through {#each_envelope};
      # push sources (a streaming callback) use a {Writer} directly.
      class Bridge
        attr_reader :message_id, :library_version

        def initialize(message_id:, library_version: nil, configuration: OpenUI::Rails.configuration)
          @message_id = message_id
          @library_version = library_version
          @configuration = configuration
        end

        # @param source [#each] yields String chunks
        # @return [Enumerator<Envelope>]
        def envelopes(source)
          to_enum(:each_envelope, source)
        end

        def each_envelope(source)
          writer = writer()
          source.each do |chunk|
            writer.push(chunk).each { |envelope| yield envelope }
          end
          writer.finish.each { |envelope| yield envelope }
        rescue StandardError => e
          yield writer.error_for(e)
        end

        # Build a stateful writer for push-based providers.
        def writer
          Writer.new(
            message_id: message_id,
            library_version: library_version,
            pending_byte_limit: @configuration.pending_byte_limit,
            stream_byte_limit: @configuration.stream_byte_limit,
            on_error: @configuration.on_error
          )
        end

        # Accumulates pushed chunks and emits envelopes. Stateful across calls.
        class Writer
          attr_reader :sequence

          def initialize(message_id:, library_version: nil, pending_byte_limit:, stream_byte_limit:, on_error: nil)
            @message_id = message_id
            @library_version = library_version
            @pending_byte_limit = pending_byte_limit
            @stream_byte_limit = stream_byte_limit
            @on_error = on_error
            @sequence = 0
            @total_bytes = 0
            @pending = +""
            @overflowed = false
          end

          # @return [Array<Envelope>] zero or more envelopes to emit
          def push(chunk)
            return [] if @overflowed || chunk.nil? || chunk.empty?

            @total_bytes += chunk.bytesize
            if @total_bytes > @stream_byte_limit
              @overflowed = true
              return [ error_envelope("stream_too_large", "stream exceeded #{@stream_byte_limit} bytes") ]
            end

            @pending << chunk
            return [] if @pending.bytesize < @pending_byte_limit

            [ flush_delta ]
          end

          # @return [Array<Envelope>] the final delta (if any) and completion
          def finish
            return [] if @overflowed

            envelopes = []
            envelopes << flush_delta unless @pending.empty?
            envelopes << Envelope.completed(
              message_id: @message_id, sequence: @sequence, library_version: @library_version
            )
            @sequence += 1
            envelopes
          end

          # Structured, PII-free error envelope for a provider/consumer failure.
          def error_for(error, code: "stream_failed")
            @on_error&.call(error, message_id: @message_id)

            message = "stream failed (#{error.class})"
            message = "stream cancelled" if code == "stream_cancelled"
            error_envelope(code, message)
          end

          private

          def flush_delta
            envelope = Envelope.delta(
              message_id: @message_id, sequence: @sequence, delta: @pending.dup,
              library_version: @library_version, streaming: true
            )
            @sequence += 1
            @pending = +""
            envelope
          end

          def error_envelope(code, message)
            Envelope.error(
              message_id: @message_id, sequence: @sequence, library_version: @library_version,
              code: code, message: message
            )
          end
        end
      end
    end
  end
end
