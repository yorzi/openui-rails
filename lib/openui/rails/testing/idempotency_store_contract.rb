# frozen_string_literal: true

module OpenUI
  module Rails
    module Testing
      # Reusable Minitest contract for idempotency adapters. Include this module
      # in a test case that defines build_store and advance_store_clock(seconds).
      # Each test needs an empty store and a controllable shared clock.
      module IdempotencyStoreContract
        def test_claim_distinguishes_pending_from_completed
          store = build_store
          status, value, digest, token = store.claim("key", ttl: 60, digest: "original")
          assert_equal :claimed, status
          assert_nil value
          assert_equal "original", digest
          refute_empty token
          assert_equal [ :pending, nil, "original", token ], store.claim("key", ttl: 60, digest: "changed")
          store.record("key", "saved", claim_token: token)
          assert_equal [ :replay, "saved", "original", token ], store.claim("key", ttl: 60, digest: "changed")
        end

        def test_completed_nil_and_false_replay
          store = build_store
          [ nil, false ].each_with_index do |value, index|
            key = "nullable-#{index}"
            token = store.claim(key, ttl: 60, digest: "d").last
            store.record(key, value, claim_token: token)
            assert_equal [ :replay, value, "d", token ], store.claim(key, ttl: 60, digest: "d")
          end
        end

        def test_json_results_round_trip
          store = build_store
          value = { "list" => [ 1, 2.5, true, false, nil, "你好" ], "nested" => { "ok" => true } }
          token = store.claim("key", ttl: 60, digest: "d").last
          store.record("key", value, claim_token: token)
          assert_equal value, store.claim("key", ttl: 60, digest: "d")[1]
        end

        def test_expired_owner_cannot_record
          store = build_store
          token = store.claim("key", ttl: 10, digest: "old").last
          advance_store_clock(10)
          store.record("key", "late", claim_token: token)
          status, value, _, replacement = store.claim("key", ttl: 60, digest: "new")
          assert_equal :claimed, status
          assert_nil value
          refute_equal token, replacement
        end

        def test_replaced_owner_cannot_overwrite
          store = build_store
          old = store.claim("key", ttl: 10, digest: "old").last
          advance_store_clock(11)
          token = store.claim("key", ttl: 60, digest: "new").last
          store.record("key", "new result", claim_token: token)
          store.record("key", "old result", claim_token: old)
          assert_equal [ :replay, "new result", "new", token ], store.claim("key", ttl: 60, digest: "new")
        end

        def test_wrong_token_and_unknown_key_do_not_complete_a_claim
          store = build_store
          token = store.claim("key", ttl: 60, digest: "d").last
          store.record("missing", "value", claim_token: token)
          store.record("key", "value", claim_token: "wrong")
          assert_equal :pending, store.claim("key", ttl: 60, digest: "d").first
          assert_equal :claimed, store.claim("missing", ttl: 60, digest: "d").first
        end

        def test_ttl_must_be_positive_and_finite
          store = build_store
          [ 0, -1, Float::INFINITY, Float::NAN, "60", nil ].each do |ttl|
            assert_raises(OpenUI::Rails::ConfigurationError) { store.claim("key", ttl: ttl, digest: "d") }
          end
        end
      end
    end
  end
end
