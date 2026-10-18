---
layout: default
title: Upgrading
nav_order: 2
description: Move an OpenUI Rails application between documented gem releases with the required code and configuration changes.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to install the first gem release.
* Which changes affect applications built from an earlier Git checkout.

## Install version {{ site.version }}

Replace a Git dependency with the published gem in your application's `Gemfile`:

```ruby
gem "openui-rails", "~> {{ site.version }}"
```

Run `bundle update openui-rails`. New applications can follow [Getting Started]({% link _getting_started/getting-started.md %}). This is the first gem release, so there is no upgrade from an earlier published version.

## Move from a development checkout

If your application used an earlier Git revision, review these changes:

* Custom idempotency stores distinguish pending claims from completed replays, return a claim token, and accept `record(..., claim_token:)`. See [Configuration]({% link _getting_started/configuration.md %}).
* The engine inherits your host's `ApplicationController` and retains its authentication filters. This release requires full-stack controllers. API-only authentication and CSRF integration need separate qualification.
* Surface helpers and the browser verify the configured library identity. A custom prompt and spec need a matching custom browser runtime. See [Library Contract]({% link _core_features/library-contract.md %}).
* Add `<%= openui_stylesheet_tag %>` once in your layout. Fetch the pinned JavaScript, CSS, and upstream license with `bin/rails openui:runtime:fetch`. See [Runtime Assets]({% link _core_features/runtime-assets.md %}).
* Terminal stream frames use the same sequence checks as deltas. After a gap, your host must deliver an authoritative snapshot before streaming resumes. See [Streaming]({% link _core_features/streaming.md %}).

Keep database constraints and transactions around irreversible host actions. Idempotency TTL expiry and process restarts do not provide an exactly-once guarantee.

## Next Steps

* [What's New]({% link _getting_started/whats-new.md %}) - see the current feature overview.
* [Release History]({% link _reference/release-history.md %}) - check published versions.
