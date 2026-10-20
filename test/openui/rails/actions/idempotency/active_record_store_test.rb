# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "open3"
require "timeout"
require "openui/rails/testing/idempotency_store_contract"

class IdempotencyTestRecord < ActiveRecord::Base
  self.table_name = "openui_action_claims"
end

class ActiveRecordStoreTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  include OpenUI::Rails::Testing::IdempotencyStoreContract

  setup do
    @directory = Dir.mktmpdir("openui-store-")
    @database = File.join(@directory, "claims.sqlite3")
    @now = Time.now.utc
    IdempotencyTestRecord.establish_connection(adapter: "sqlite3", database: @database, timeout: 5000)
    template = File.expand_path("../../../../../lib/generators/openui/idempotency/templates/create_openui_action_claims.rb", __dir__)
    load template unless defined?(CreateOpenUIActionClaims)
    ActiveRecord::Migration.suppress_messages do
      IdempotencyTestRecord.connection_pool.with_connection { |connection| CreateOpenUIActionClaims.new.exec_migration(connection, :up) }
    end
  end

  teardown do
    IdempotencyTestRecord.remove_connection
    FileUtils.remove_entry(@directory) if @directory
  end

  def build_store
    OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new(model: IdempotencyTestRecord, clock: -> { @now })
  end

  def advance_store_clock(seconds)
    @now += seconds
  end

  test "completed results survive reconnect and store replacement" do
    store = build_store
    token = store.claim("key", ttl: 60, digest: "d").last
    store.record("key", { answer: false }, claim_token: token)
    IdempotencyTestRecord.connection_pool.disconnect!
    assert_equal [ :replay, { "answer" => false }, "d", token ], build_store.claim("key", ttl: 60, digest: "d")
  end

  test "cleanup deletes only expired rows and fences old tokens" do
    store = build_store
    old = store.claim("old", ttl: 1, digest: "d").last
    live = store.claim("live", ttl: 60, digest: "d").last
    advance_store_clock(1)
    assert_equal 1, store.delete_expired
    assert_equal 0, store.delete_expired
    store.record("old", "late", claim_token: old)
    assert_equal [ :pending, nil, "d", live ], store.claim("live", ttl: 60, digest: "d")
    assert_equal :claimed, store.claim("old", ttl: 60, digest: "new").first
  end

  test "unsupported results fail without recording success" do
    store = build_store
    token = store.claim("key", ttl: 60, digest: "d").last
    [ Object.new, Float::NAN, { a: 1, "a" => 2 } ].each do |value|
      assert_raises(OpenUI::Rails::ConfigurationError) { store.record("key", value, claim_token: token) }
    end
    assert_equal :pending, store.claim("key", ttl: 60, digest: "d").first
  end

  test "independent processes admit one owner for a new and an expired key" do
    2.times do |round|
      if round == 1
        IdempotencyTestRecord.where(key: "shared").update_all(expires_at: Time.now.utc - 60)
      end
      claims = run_workers(4)
      assert_equal 1, claims.count { |claim| claim.first == "claimed" }
      assert_equal 3, claims.count { |claim| %w[pending replay].include?(claim.first) }
      assert_equal 1, IdempotencyTestRecord.where(key: "shared").count
      replay = build_store.claim("shared", ttl: 60, digest: "d")
      assert_equal :replay, replay.first
      assert_equal false, replay[1]
    end
  end

  test "a process that exits before recording leaves a pending claim until expiry" do
    claim = run_workers(1, "abandon").first
    assert_equal "claimed", claim.first
    assert_equal :pending, build_store.claim("shared", ttl: 60, digest: "d").first
    advance_store_clock(120)
    replacement = build_store.claim("shared", ttl: 60, digest: "d")
    assert_equal :claimed, replacement.first
    build_store.record("shared", "late result", claim_token: claim.last)
    assert_equal :pending, build_store.claim("shared", ttl: 60, digest: "d").first
  end

  test "dispatcher rejects changed requests and isolates actor and tenant replays" do
    registry = OpenUI::Rails::Actions::Registry.new
    calls = []
    registry.register("close", schema: {}, authorize: ->(*) { true }, handler: ->(invocation) {
      calls << [ invocation.actor, invocation.tenant ]
      { "actor" => invocation.actor, "tenant" => invocation.tenant }
    })
    dispatcher = -> {
      OpenUI::Rails::Actions::Dispatcher.new(registry: registry, idempotency_store: build_store, idempotency_ttl: 60)
    }
    payload = { action: "close", args: {}, surface_id: "one", version: 1, idempotency_key: "shared" }
    first = dispatcher.call.call(payload, actor: "alice", tenant: "north")
    refute first.replayed?
    replay = dispatcher.call.call(payload, actor: "alice", tenant: "north")
    assert replay.replayed?
    assert_equal first.value, replay.value
    assert_raises(OpenUI::Rails::ReplayError) do
      dispatcher.call.call(payload.merge(surface_id: "changed"), actor: "alice", tenant: "north")
    end
    refute dispatcher.call.call(payload, actor: "bob", tenant: "north").replayed?
    refute dispatcher.call.call(payload, actor: "alice", tenant: "south").replayed?
    assert_equal 3, calls.size
  end

  private

  def run_workers(count, mode = "complete")
    workers = count.times.map do
      Open3.popen3(RbConfig.ruby, "-Ilib", "test/support/idempotency_worker.rb", @database, mode,
        chdir: File.expand_path("../../../../..", __dir__))
    end
    Timeout.timeout(30) do
      workers.each { |_, output, _, _| assert_equal "ready\n", output.gets }
      workers.each { |input, _, _, _| input.puts "go"; input.close }
      workers.map do |_, output, errors, waiter|
        value = output.read
        assert waiter.value.success?, errors.read
        JSON.parse(value)
      end
    end
  ensure
    workers&.each do |input, output, errors, waiter|
      Process.kill("TERM", waiter.pid) if waiter.alive?
      waiter.join
      [ input, output, errors ].each { |io| io.close unless io.closed? }
    end
  end
end
