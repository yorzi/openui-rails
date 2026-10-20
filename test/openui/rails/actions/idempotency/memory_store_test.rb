# frozen_string_literal: true

require "test_helper"
require "openui/rails/testing/idempotency_store_contract"

module OpenUI
  module Rails
    module Actions
      module Idempotency
        class MemoryStoreTest < ActiveSupport::TestCase
          include OpenUI::Rails::Testing::IdempotencyStoreContract
          setup { @now = 0.0; @store = MemoryStore.new }

          def build_store
            MemoryStore.new(clock: -> { @now })
          end

          def advance_store_clock(seconds)
            @now += seconds
          end

          test "the first claim succeeds and the second reports a replay" do
            status, _, digest, token = @store.claim("k", ttl: 60, digest: "digest")
            assert_equal :claimed, status
            assert_equal "digest", digest

            @store.record("k", "result", claim_token: token)

            assert_equal [ :replay, "result", "digest", token ], @store.claim("k", ttl: 60, digest: "digest")
          end

          test "a replay before the result is recorded returns nil" do
            @store.claim("k", ttl: 60, digest: "digest")

            assert_equal [ :pending, nil, "digest" ], @store.claim("k", ttl: 60, digest: "digest").first(3)
          end

          test "entries expire after the ttl" do
            now = 0.0
            store = MemoryStore.new(clock: -> { now })

            store.claim("k", ttl: 10, digest: "d")
            now = 11.0

            assert_equal :claimed, store.claim("k", ttl: 10, digest: "d").first
          end

          test "record is a no-op for an unknown key" do
            assert_nil @store.record("missing", "result", claim_token: "missing")
          end

          test "an expired writer cannot overwrite a newer claim" do
            now = 0.0
            store = MemoryStore.new(clock: -> { now })
            old_token = store.claim("k", ttl: 10, digest: "old").last
            now = 11.0
            new_token = store.claim("k", ttl: 10, digest: "new").last
            store.record("k", "new result", claim_token: new_token)
            store.record("k", "old result", claim_token: old_token)

            assert_equal [ :replay, "new result", "new", new_token ], store.claim("k", ttl: 10, digest: "new")
          end

          test "concurrent claims admit exactly one owner" do
            results = 16.times.map do
              Thread.new { @store.claim("shared", ttl: 60, digest: "d").first }
            end.map(&:value)

            assert_equal 1, results.count(:claimed)
            assert_equal 15, results.count(:pending)
          end
        end
      end
    end
  end
end
