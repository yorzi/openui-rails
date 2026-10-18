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
          source = source.to_enum
          loop do
            begin
              chunk = source.next
              envelopes = writer.push(chunk)
            rescue StopIteration
              break
            rescue StandardError => error
              envelope = writer.error_for(error)
              yield envelope if envelope
              return
            end
            # Transport/consumer failures are not provider failures. Let the
            # host retry or report them without recursively broadcasting errors.
            envelopes.each { |envelope| yield envelope }
          end
          writer.finish.each { |envelope| yield envelope }
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
            Envelope.completed(message_id: message_id, sequence: 0, library_version: library_version)
            unless pending_byte_limit.is_a?(Integer) && stream_byte_limit.is_a?(Integer) &&
                pending_byte_limit > 0 && stream_byte_limit >= pending_byte_limit
              raise ConfigurationError, "stream limits must be positive integers with pending <= total"
            end
            @message_id = message_id
            @library_version = library_version
            @pending_byte_limit = pending_byte_limit
            @stream_byte_limit = stream_byte_limit
            @on_error = on_error
            @sequence = 0
            @total_bytes = 0
            @pending = +""
            @terminated = false
          end

          # @return [Array<Envelope>] zero or more envelopes to emit
          def push(chunk)
            return [] if @terminated || chunk.nil?
            raise StreamError, "stream chunks must be strings" unless chunk.is_a?(String)
            return [] if chunk.empty?

            @total_bytes += chunk.bytesize
            if @total_bytes > @stream_byte_limit
              return [ error_envelope("stream_too_large", "stream exceeded #{@stream_byte_limit} bytes") ]
            end

            @pending << chunk
            return [] if @pending.bytesize < @pending_byte_limit

            [ flush_delta ]
          end

          # @return [Array<Envelope>] the final delta (if any) and completion
          def finish
            return [] if @terminated

            envelopes = []
            envelopes << flush_delta unless @pending.empty?
            envelopes << Envelope.completed(
              message_id: @message_id, sequence: @sequence, library_version: @library_version
            )
            @sequence += 1
            @terminated = true
            envelopes
          end

          # Structured, PII-free error envelope for a provider/consumer failure.
          def error_for(error, code: "stream_failed")
            return nil if @terminated

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
            envelope = Envelope.error(
              message_id: @message_id, sequence: @sequence, library_version: @library_version,
              code: code, message: message
            )
            @sequence += 1
            @terminated = true
            @pending.clear
            envelope
          end
        end
      end
    end
  end
end
