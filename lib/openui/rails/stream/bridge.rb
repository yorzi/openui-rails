# frozen_string_literal: true

require "openui/rails/instrumentation"

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

        # Create a bridge with message metadata and configured byte limits.
        #
        # @param message_id [String] stable id shared by all frames in the stream
        #
        # @param library_version [String, nil] manifest fingerprint attached to frames
        #
        # @param configuration [Configuration]
        #
        # @return [Bridge]
        def initialize(message_id:, library_version: nil, configuration: OpenUI::Rails.configuration)
          @message_id = message_id
          @library_version = library_version
          @configuration = configuration
        end

        # @param source [#each] yields String chunks
        #
        # @return [Enumerator<Envelope>]
        def envelopes(source)
          to_enum(:each_envelope, source)
        end

        # Yield ordered envelopes for every chunk from a pull-based source.
        # Provider errors become a structured error envelope. Exceptions raised
        # by the consumer block propagate to the caller. Pulling stops once the
        # writer terminates, so an oversized response does not drain the source.
        #
        # @param source [#each] yields String chunks
        # @yieldparam envelope [Envelope]
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
            return if writer.terminated?
          end
          writer.finish.each { |envelope| yield envelope }
        end

        # Build a stateful writer for push-based providers.
        #
        # @return [Writer]
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

          # Create a writer that buffers chunks up to the pending byte limit.
          #
          # @param message_id [String]
          #
          # @param library_version [String, nil]
          #
          # @param pending_byte_limit [Integer]
          #
          # @param stream_byte_limit [Integer]
          #
          # @param on_error [#call, nil]
          #
          # @return [Writer]
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
            @started = Instrumentation.now
          end

          # Whether a completion or error envelope has ended this stream. Stop
          # reading the provider once it is true; later pushes are ignored.
          #
          # @return [Boolean]
          def terminated? = @terminated

          # Append a chunk and return a delta once the pending threshold is reached.
          # A chunk that exceeds the total stream limit returns an error envelope.
          #
          # @param chunk [String, nil]
          #
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

          # Flush pending text and emit the completion envelope once. A terminal
          # stream.openui_rails notification describes creation, not delivery.
          #
          # @return [Array<Envelope>] the final delta, if any, and completion
          def finish
            return [] if @terminated

            envelopes = []
            envelopes << flush_delta unless @pending.empty?
            envelopes << Envelope.completed(
              message_id: @message_id, sequence: @sequence, library_version: @library_version
            )
            @sequence += 1
            @terminated = true
            notify_termination("completed")
            envelopes
          end

          # Structured, PII-free error envelope for a provider/consumer failure.
          # Calls `on_error` first; an exception raised by that hook is ignored.
          #
          # @param error [Exception]
          #
          # @param code [String] a supported stream error code
          #
          # @return [Envelope, nil] nil when the writer already terminated
          def error_for(error, code: "stream_failed")
            return nil if @terminated

            notify_error(error)

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
            notify_termination(code == "stream_cancelled" ? "cancelled" : "failed", code)
            envelope
          end

          # A failing host hook must not suppress the terminal frame or replace
          # the provider error, matching notification subscriber isolation.
          def notify_error(error)
            @on_error&.call(error, message_id: @message_id)
          rescue StandardError
            nil
          end

          def notify_termination(outcome, code = nil)
            Instrumentation.publish("stream", started: @started, outcome: outcome,
              code: code, sequence: @sequence - 1, bytes: @total_bytes)
          end
        end
      end
    end
  end
end
