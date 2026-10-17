# frozen_string_literal: true

require "test_helper"

module OpenUI
  module Rails
    module Actions
      module Idempotency
        class MemoryStoreTest < ActiveSupport::TestCase
          setup { @store = MemoryStore.new }

          test "the first claim succeeds and the second reports a replay" do
            assert_equal [ :claimed, nil, "digest" ], @store.claim("k", ttl: 60, digest: "digest")

            @store.record("k", "result")

            assert_equal [ :replay, "result", "digest" ], @store.claim("k", ttl: 60, digest: "digest")
          end

          test "a replay before the result is recorded returns nil" do
            @store.claim("k", ttl: 60, digest: "digest")

            assert_equal [ :replay, nil, "digest" ], @store.claim("k", ttl: 60, digest: "digest")
          end

          test "entries expire after the ttl" do
            now = 0.0
            store = MemoryStore.new(clock: -> { now })

            store.claim("k", ttl: 10, digest: "d")
            now = 11.0

            assert_equal :claimed, store.claim("k", ttl: 10, digest: "d").first
          end

          test "record is a no-op for an unknown key" do
            assert_nil @store.record("missing", "result")
          end
        end
      end
    end
  end
end
