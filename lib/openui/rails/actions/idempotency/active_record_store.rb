# frozen_string_literal: true

require "active_record"
require "json"
require "securerandom"

module OpenUI
  module Rails
    module Actions
      module Idempotency
        # Optional shared action store. Verified with SQLite on Rails 8.0/8.1.
        # Install its table with `rails generate openui:idempotency` and db:migrate.
        # JSON values replay across workers; object keys become strings. TTL runs
        # from claim creation, not completion. Never assumes exactly-once effects.
        class ActiveRecordStore
          class Entry < ::ActiveRecord::Base # :nodoc:
            self.table_name = "openui_action_claims"
          end
          private_constant :Entry

          # @param model [Class] dedicated Active Record model, optionally using another database
          # @param clock [#call] shared wall clock returning UTC Time values
          def initialize(model: Entry, clock: -> { Time.now.utc })
            @model = model
            @clock = clock
          end

          # Atomically insert or replace an expired claim. Returns the same
          # [status, result, stored_digest, token] contract as MemoryStore.
          # A changed digest is returned to the dispatcher, which rejects it.
          def claim(key, ttl:, digest: nil)
            raise ConfigurationError, "idempotency ttl must be positive" unless ttl.is_a?(Numeric) && ttl.finite? && ttl > 0

            loop do
              now = @clock.call
              attributes = { key: key, digest: digest, claim_token: SecureRandom.hex(16),
                             completed: false, result_json: nil, expires_at: now + ttl }
              inserted = @model.insert_all([ attributes ], unique_by: :key, returning: %w[id])
              return [ :claimed, nil, digest, attributes[:claim_token] ] if inserted.any?

              replaced = @model.where(key: key).where("expires_at <= ?", now).update_all(attributes.except(:key))
              return [ :claimed, nil, digest, attributes[:claim_token] ] if replaced == 1

              # Cleanup can delete the expired row between SQL statements.
              entry = @model.find_by(key: key)
              next unless entry

              value = entry.completed ? JSON.parse(entry.result_json) : nil
              return [ entry.completed ? :replay : :pending, value, entry.digest, entry.claim_token ]
            end
          end

          # Record only while this token owns a live claim. JSON encoding rejects
          # unsupported Ruby objects before writing; it never invokes Marshal.
          def record(key, result, claim_token:)
            json = JSON.generate(JsonValue.copy(result))
            @model.where(key: key, claim_token: claim_token).where("expires_at > ?", @clock.call)
              .update_all(result_json: json, completed: true)
            nil
          rescue ArgumentError, JSON::GeneratorError => error
            raise ConfigurationError, "idempotency result must be a JSON value: #{error.message}"
          end

          # Delete expired claims, returning the number removed. Call from a host
          # maintenance task; expiry of the requested key never needs this sweep.
          def delete_expired
            @model.where("expires_at <= ?", @clock.call).delete_all
          end
        end
      end
    end
  end
end
