# frozen_string_literal: true

# A separate Ruby VM and database connection, never inherited from the parent.
require "bundler/setup"
require "openui/rails"
require "active_record"

class WorkerClaim < ActiveRecord::Base
  self.table_name = "openui_action_claims"
end
WorkerClaim.establish_connection(adapter: "sqlite3", database: ARGV.fetch(0), timeout: 5000)
WorkerClaim.connection_pool.with_connection { |connection| connection.select_value("SELECT 1") }
store = OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new(model: WorkerClaim)
$stdout.sync = true
puts "ready"
abort "missing start signal" unless $stdin.gets == "go\n"
claim = store.claim("shared", ttl: 60, digest: "d")
store.record("shared", false, claim_token: claim.last) if claim.first == :claimed && ARGV[1] != "abandon"
puts JSON.generate(claim)
WorkerClaim.remove_connection
