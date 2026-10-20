---
layout: default
title: What's New in 0.4
nav_order: 4
parent: Release History
description: Share action claims and JSON results across Rails workers with optional SQLite storage.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to opt into shared action storage without replacing the default store.
* Which concurrency and crash boundaries the SQLite adapter verifies.

Version 0.4 adds optional shared replay storage. The stable site follows the
latest published release.

## Share action results

```sh
bin/rails generate openui:idempotency
bin/rails db:migrate
```

```ruby
config.idempotency_store = OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new
```

SQLite stores claim ownership and JSON results across workers and restarts.
The default remains process-local memory. Read
[Shared Idempotency Storage]({% link _advanced/shared-idempotency.md %}) before
configuring a database, result serialization, TTL, or cleanup.

## Verify the boundary

Independent Ruby processes compete against one real SQLite database for both
new and expired keys. The tests also cover completed `nil` and `false` results,
request mismatch, actor and tenant isolation, process exit, and expired-writer
fencing. A reusable Minitest contract helps hosts test another adapter.

The support-desk reference now opts into this store while keeping its business
receipt constraint. A crash after a business effect still needs that constraint;
shared claims do not guarantee exactly-once effects.

## Next Steps

* [Upgrading]({% link _reference/upgrading.md %}) - review opt-in migration steps.
* [Reference Workflow]({% link _getting_started/reference-workflow.md %}) - run the example from the built gem.
