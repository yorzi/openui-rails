---
layout: default
title: Upgrading
nav_order: 2
description: Adopt outcome notifications and explicit recovery while preserving your host authorization and replay storage.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to test the 0.5 development branch.
* Which notification and browser behavior changes need review.
* How to retain host-owned recovery and business safeguards.

## Upgrade from 0.4.0

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

Run `bundle update openui-rails`. No new migration or configuration is required.
Keep your selected replay store, library files, authorization, and business
constraints. For an older host, first read the
[0.4 migration guide](https://github.com/yorzi/openui-rails/blob/v0.4.0/docs/_reference/upgrading.md).

## Review diagnostics

Server notifications are additive. Read
[Diagnostics and Recovery]({% link _advanced/diagnostics-and-recovery.md %}) before
subscribing. Use payload `duration_ms` for operation timing; the notification's
own duration measures delivery. Default payloads exclude content and exceptions.
Your optional `on_error` callback still receives a raw exception.

Browser errors now always have a code, including `runtime_load_failed` and
`network_error`. The bridge no longer logs raw error objects to the console.
Subscribe to `openui:error` if you need host-controlled feedback or logging;
its message may contain application data. Existing action and state events
retain their payloads.

## Review recovery and lifecycle code

Use `openui:ready` for runtime and library readiness and
`openui:snapshot-applied` to acknowledge an accepted snapshot. Neither promises
that generated source has rendered successfully. Preserve visible fallback when
a subsequent renderer error occurs. Rejecting a snapshot emits no success event.

Disconnected renderer callbacks and action requests cannot report into a new
connection. Your host must apply the same abort and stale-response guards to its
own streams, state saves, and snapshot reads. Remove listeners before Turbo
caches the page. The gem does not persist or authorize host snapshots.

The reference example adds ordinary HTML ticket information, native recovery
controls, and a fresh sign-in. Its files belong to the host; review changes
before copying them over custom application code. Do not rerun the base
installer or replace a working library to adopt recovery UI.

A failed request does not prove that a mutation did nothing. Reload canonical
state or reconcile a receipt rather than automatically retrying an uncertain
action. Keep explicit confirmation, tenant scope, and database constraints.

## Plan a rollback

Existing storage and schema stay compatible with 0.4. Review host listeners that
expect the new ready or snapshot-applied events before downgrading; preserve
ordinary HTML fallback if those events are absent. Do not drop shared-store or
business tables as part of a browser-code rollback.

## Next Steps

* [What's New]({% link _getting_started/whats-new-in-0-5.md %}) - review the candidate scope.
* [Reference Workflow]({% link _getting_started/reference-workflow.md %}) - exercise recovery with a built gem.
