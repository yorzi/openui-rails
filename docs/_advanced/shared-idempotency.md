---
layout: default
title: Shared Idempotency Storage
nav_order: 4
description: Coordinate action claims across Rails workers with an optional SQLite-backed Active Record store.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to install and configure shared action storage.
* How results, ownership tokens, and expiry work across processes.
* How to test another adapter and protect business effects after a crash.

## Install the shared table

Use shared storage when more than one worker can receive an action, or when
completed results must survive a restart. With SQLite configured in your host:

```sh
bin/rails generate openui:idempotency
bin/rails db:migrate
```

Then add this setting to `config/initializers/openui.rb`:

```ruby
OpenUI::Rails.configure do |config|
  config.idempotency_store = OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new
  config.idempotency_ttl = 900
end
```

The base installer creates no database table and keeps `MemoryStore` as the
default. Existing hosts opt in explicitly. All workers must share the same
persistent SQLite database file on the same machine; separate local files do
not coordinate. Configure an appropriate SQLite busy timeout. Database errors
propagate before execution when a claim cannot be acquired. PostgreSQL, Redis,
network filesystems, and separate-machine SQLite deployments are not verified.

## Preserve ownership across workers

The generated `openui_action_claims` table has a unique index on `key`.
`insert_all` skips an existing key. A conditional update replaces a row only
when it has expired. These database operations determine ownership atomically;
a cache read followed by a write cannot replace them.

Each claim gets a random ownership token. `record` updates only a live row
whose key and token match. An expired worker cannot complete or overwrite a
replacement claim. The dispatcher compares the stored request digest before
replaying and rejects a changed action, surface, revision, arguments, or
confirmation value. It still authorizes the actor and checks the surface
revision before looking up a replay. A stale action can therefore return a
stale-surface error rather than a cached result.

Actor and tenant scoping remains the host's responsibility. See the
[shared contract]({% link _getting_started/configuration.md %}#shared-idempotency-store-contract)
for `claim` and `record`, or run the
[reference workflow]({% link _getting_started/reference-workflow.md %}) for the
complete scoped action path and its business uniqueness constraint.

## Return JSON values

Handlers using this store return JSON-compatible strings, finite numbers,
booleans, null, arrays, and objects. Ruby symbol keys become strings on replay.
Return a record's explicit public fields instead of the Active Record object.
Dates, symbols as values, and arbitrary Ruby objects are rejected. No Marshal
payload is stored or loaded. Completed `nil` and `false` values replay as
completed results rather than pending claims.

JSON is stored in a text column. Treat results as application data: return only
necessary fields, protect database and backup access, and avoid storing secrets.
If serialization fails after a handler ran, its claim stays pending; the
business effect may already exist. Do not automatically retry the mutation.

## Set expiry and cleanup

TTL begins when the claim is acquired and does not extend on completion or
replay. Use synchronized wall clocks across workers and choose a TTL longer
than the expected operation. There is no lease renewal. A worker that outlives
its TTL can overlap a replacement even though its late result is fenced out.

Expired keys can be reclaimed without a cleanup job. To remove other expired
rows, call this from your application's maintenance task:

```ruby
OpenUI::Rails.configuration.idempotency_store.delete_expired
# => number of deleted rows
```

Cleanup uses the expiry index and deletes only expired rows. Schedule it at a
rate appropriate for your workload; the gem starts no scheduler or background
process. Replay retention ends at expiry.

The default model uses `ActiveRecord::Base`'s connection. You can pass a dedicated
model with the generated schema to use your host's own connection configuration:

```ruby
store = OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new(model: ActionClaim)
```

Keep that model free of default scopes and callbacks; the store uses direct
insert and update operations. Calls participate in an enclosing transaction on
that connection. Keep claims outside business transactions when they must be
durable independently. A surrounding rollback also rolls back the claim.

## Keep business constraints after a crash

A process can stop after committing a business effect and before recording its
result. The shared row stays pending until expiry. A later claim can run the
handler again. Enforce a unique business operation key and write its receipt
in the same database transaction as the mutation, as the support-desk reference
does. External effects need their own idempotency or reconciliation mechanism.
Shared replay storage does not provide exactly-once execution.

## Test your adapter

The shipped Minitest contract exercises pending and completed results,
`nil` and `false`, JSON results, digest preservation, expiry, and stale tokens.
Provide a fresh store and a controllable clock for each test:

```ruby
require "openui/rails/testing/idempotency_store_contract"

class MyStoreTest < ActiveSupport::TestCase
  include OpenUI::Rails::Testing::IdempotencyStoreContract

  setup { @now = Time.now.utc }

  def build_store
    MyStore.new(clock: -> { @now }) # use an empty, isolated store per test
  end

  def advance_store_clock(seconds)
    @now += seconds
  end
end
```

Each example adapter must share its controllable clock with the test. Also
verify independent-process claims, connection restart, and persistence against
your real backend. This contract alone cannot prove atomicity across workers.

## Next Steps

* [Production Considerations]({% link _advanced/production.md %}) - review host boundaries.
* [Server Actions]({% link _core_features/actions.md %}) - register and authorize handlers.
* [Reference Workflow]({% link _getting_started/reference-workflow.md %}) - inspect the persisted example.
