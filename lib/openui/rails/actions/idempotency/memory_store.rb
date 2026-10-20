# frozen_string_literal: true

require "securerandom"

module OpenUI
  module Rails
    module Actions
      module Idempotency
        # Default, single-process idempotency store. Hosts that run multiple
        # processes can opt into ActiveRecordStore on SQLite
        # or inject another shared adapter implementing the same contract.
        #
        # Contract:
        #   claim(key, ttl:, digest:) -> [status, result, digest, claim_token]
        #   status is :claimed, :pending or :replay (even for a nil result).
        #   record(key, result, claim_token:) ignores an expired/replaced claim.
        class MemoryStore
          def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
            @entries = {}
            @mutex = Mutex.new
            @clock = clock
          end

          def claim(key, ttl:, digest: nil)
            raise ConfigurationError, "idempotency ttl must be positive" unless ttl.is_a?(Numeric) && ttl.finite? && ttl > 0

            @mutex.synchronize do
              now = @clock.call
              purge(now)

              if (entry = @entries[key])
                return [ entry[:completed] ? :replay : :pending, entry[:result], entry[:digest], entry[:token] ]
              end

              token = SecureRandom.hex(16)
              @entries[key] = { digest: digest, result: nil, completed: false, token: token, expires_at: now + ttl }
              [ :claimed, nil, digest, token ]
            end
          end

          def record(key, result, claim_token:)
            @mutex.synchronize do
              entry = @entries[key]
              if entry && entry[:token] == claim_token && entry[:expires_at] > @clock.call
                entry[:result] = result
                entry[:completed] = true
              end
            end
          end

          def size
            @mutex.synchronize { @entries.size }
          end

          private

          def purge(now)
            @entries.reject! { |_key, entry| entry[:expires_at] <= now }
          end
        end
      end
    end
  end
end
