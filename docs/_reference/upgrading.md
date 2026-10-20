---
layout: default
title: Upgrading
nav_order: 2
description: Opt into shared action storage while preserving existing OpenUI Rails applications and their authorization rules.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to upgrade an application to 0.4.0.
* How to opt into shared storage and prepare JSON handler results.

## Upgrade from 0.3.0

{% if site.docs_unreleased %}This channel follows `main`.
{% unless site.released %}Version `{{ site.version }}` is an unpublished candidate.{% endunless %}

```ruby
gem "openui-rails", git: "https://github.com/yorzi/openui-rails", branch: "main"
```
{% else %}Set the version in your application's `Gemfile`:

```ruby
gem "openui-rails", "~> {{ site.version }}"
```
{% endif %}

Run `bundle update openui-rails`. Existing applications keep `MemoryStore` and
need no migration or initializer change. For older applications, first read
the [0.3 migration guide](https://github.com/yorzi/openui-rails/blob/v0.3.0/docs/_reference/upgrading.md).

## Opt into shared storage

```sh
bin/rails generate openui:idempotency
bin/rails db:migrate
```

```ruby
config.idempotency_store = OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new
```

All workers must use the same SQLite database. Run the migration before enabling
the setting. Review handlers before switching: the database adapter accepts JSON
values and normalizes object keys to strings. Return explicit public fields
instead of arbitrary Ruby objects. Memory-store results are not migrated;
coordinate the switch with outstanding requests because old claims do not move.
Do not replace or drop the existing library or rerun the base installer.

Read [Shared Idempotency Storage]({% link _advanced/shared-idempotency.md %}) for
expiry, cleanup, clock, transaction, and crash limits. Keep host authorization,
scoped record lookup, and business uniqueness constraints. The reference host
opts into this store; existing hosts do so only when configured.

## Plan a rollback

Switching back to memory loses cross-worker coordination and access to database
replays. Drain outstanding actions before changing the store. Do not drop the
shared table while any worker still uses it. Restore a compatible library and
host schema before downgrading the gem.

## Next Steps

* [What's New]({% link _getting_started/whats-new-in-0-4.md %}) - review shared storage and its limits.
* [Release History]({% link _reference/release-history.md %}) - check published versions.
