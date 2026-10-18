# frozen_string_literal: true

module OpenUI
  module Rails
    module Stream
      # Binds the ordered {Bridge} to a transport and broadcasts every envelope
      # as it is produced.
      #
      # The transport is a seam: any object that responds to
      # `#broadcast(envelope)` works, and {Transports} ships wrappers for Action
      # Cable, Turbo Streams and an in-memory collector. Delivery is best effort:
      # Action Cable and Turbo Streams do not promise order or delivery. The
      # client applies sequence numbers and recovers from an
      # authoritative snapshot on a gap (see the Stimulus controller).
      #
      #   broadcaster = Broadcaster.new(
      #     transport: Transports::ActionCable.new("openui:surface:42"),
      #     message_id: "msg-1",
      #     library_version: OpenUI::Rails.configuration.library_fingerprint
      #   )
      #   chat.complete { |chunk| broadcaster.push(chunk.content) }
      #   broadcaster.finish
      class Broadcaster
        attr_reader :transport, :message_id, :library_version

        # Broadcast every envelope produced by an enumerable source of chunks.
        #
        # @param source [#each] yields String chunks
        # @param options [Hash] arguments forwarded to the constructor
        #
        # @return [Broadcaster]
        def self.broadcast(source, **options)
          broadcaster = new(**options)
          source.each { |chunk| broadcaster.push(chunk) }
          broadcaster.finish
        end

        # Bind a bridge writer to a transport that responds to `broadcast`.
        #
        # @param transport [#broadcast]
        #
        # @param message_id [String]
        #
        # @param library_version [String, nil]
        #
        # @param configuration [Configuration]
        #
        # @return [Broadcaster]
        def initialize(transport:, message_id:, library_version: nil, configuration: OpenUI::Rails.configuration)
          raise ConfigurationError, "a transport is required" if transport.nil?
          unless transport.respond_to?(:broadcast)
            raise ConfigurationError, "transport must respond to #broadcast"
          end

          @transport = transport
          @message_id = message_id
          @library_version = library_version
          @configuration = configuration
          @writer = Bridge.new(
            message_id: message_id,
            library_version: library_version,
            configuration: configuration
          ).writer
        end

        # Push a chunk; broadcasts any envelopes the writer flushes.
        #
        # @param chunk [String, nil]
        #
        # @return [self]
        def push(chunk)
          @writer.push(chunk).each { |envelope| @transport.broadcast(envelope) }
          self
        end

        # Broadcast the final delta (if any) and the completion marker.
        #
        # @return [self]
        def finish
          @writer.finish.each { |envelope| @transport.broadcast(envelope) }
          self
        end

        # Broadcast a structured, PII-free error envelope and stop.
        #
        # @param error [Exception]
        #
        # @param code [String]
        #
        # @return [self]
        def fail(error, code: "stream_failed")
          envelope = @writer.error_for(error, code: code)
          @transport.broadcast(envelope) if envelope
          self
        end

        # The next sequence number the writer will assign.
        #
        def sequence = @writer.sequence

        # The underlying writer, for callers that need finer control.
        attr_reader :writer
      end
    end
  end
end
