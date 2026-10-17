# frozen_string_literal: true

module OpenUI
  module Rails
    module Actions
      module Idempotency
        # Default, single-process idempotency store. Hosts that run multiple
        # processes should inject a shared store (e.g. Redis or the database)
        # that implements the same contract.
        #
        # Contract:
        #   claim(key, ttl:, digest:) -> [:claimed, nil, digest] | [:replay, result, digest]
        #   record(key, result)
        class MemoryStore
          def initialize(clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) })
            @entries = {}
            @mutex = Mutex.new
            @clock = clock
          end

          def claim(key, ttl:, digest: nil)
            @mutex.synchronize do
              now = @clock.call
              purge(now)

              if (entry = @entries[key])
                return [ :replay, entry[:result], entry[:digest] ]
              end

              @entries[key] = { digest: digest, result: nil, expires_at: now + ttl }
              [ :claimed, nil, digest ]
            end
          end

          def record(key, result)
            @mutex.synchronize do
              entry = @entries[key]
              entry[:result] = result if entry
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
