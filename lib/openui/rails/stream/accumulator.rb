# frozen_string_literal: true

module OpenUI
  module Rails
    module Stream
      # Client-side (Ruby) sequence accumulator mirroring what the browser must
      # do: apply ordered deltas, ignore duplicates, and treat a missing
      # sequence as "fetch the authoritative snapshot" rather than executing a
      # malformed partial. Used by server tests and by hosts that consume their
      # own stream.
      class Accumulator
        attr_reader :message_id, :source

        def initialize(message_id:)
          @message_id = message_id
          @source = +""
          @next_sequence = 0
          @completed = false
          @error = nil
          @needs_snapshot = false
        end

        # @return [Symbol] one of :applied, :duplicate, :snapshot, :completed,
        #   :error, :ignored
        def apply(envelope)
          return :ignored unless envelope.message_id == message_id
          unless envelope.snapshot?
            return :duplicate if envelope.sequence < @next_sequence
            return :ignored if @completed || error?
            return :gap if @needs_snapshot
            if envelope.sequence > @next_sequence
              @needs_snapshot = true
              return :gap
            end
          end

          case envelope.type
          when Envelope::DELTA then apply_delta(envelope)
          when Envelope::SNAPSHOT then apply_snapshot(envelope)
          when Envelope::COMPLETED then apply_completed(envelope)
          when Envelope::ERROR then apply_error(envelope)
          else :ignored
          end
        end

        def next_sequence = @next_sequence
        def completed? = @completed
        def error? = !@error.nil?
        def needs_snapshot? = @needs_snapshot
        def error = @error

        private

        def apply_delta(envelope)
          @source << envelope.delta
          @next_sequence += 1
          :applied
        end

        def apply_snapshot(envelope)
          minimum = @needs_snapshot ? @next_sequence - 1 : @next_sequence
          return :duplicate if envelope.sequence < minimum

          @source = +envelope.response.dup
          @next_sequence = envelope.sequence + 1
          @needs_snapshot = false
          @completed = !envelope.streaming?
          @error = nil
          :snapshot
        end

        def apply_completed(envelope)
          @completed = true
          @next_sequence = [ @next_sequence, envelope.sequence + 1 ].max
          :completed
        end

        def apply_error(envelope)
          @error = envelope
          @next_sequence += 1
          :error
        end
      end
    end
  end
end
