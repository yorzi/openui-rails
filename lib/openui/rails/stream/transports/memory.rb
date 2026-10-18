# frozen_string_literal: true

module OpenUI
  module Rails
    module Stream
      module Transports
        # In-memory transport for tests and examples. It keeps every broadcast
        # envelope, so a caller can assert on the exact ordered sequence.
        class Memory
          attr_reader :envelopes

          def initialize
            @envelopes = []
          end

          def broadcast(envelope)
            @envelopes << envelope
            envelope
          end

          def to_a = @envelopes.dup

          def clear
            @envelopes.clear
            self
          end

          def empty? = @envelopes.empty?
        end
      end
    end
  end
end
