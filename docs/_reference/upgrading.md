---
layout: default
title: Upgrading
nav_order: 2
description: Upgrade to 0.9.0, review its action error and stream changes, and remove deprecated settings.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to upgrade your application to 0.9.0.
* Which endpoint, stream, and browser behavior changes need review.
* Which deprecated settings to remove before 1.0.

## Upgrade from 0.5.0

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

Run `bundle update openui-rails`. No new migration is required. Keep your
selected replay store, library files, authorization, and business constraints.
The pinned runtime and default library exports are unchanged, so stored
surfaces keep their library fingerprint. For an older host, first read the
[0.5 migration guide](https://github.com/yorzi/openui-rails/blob/v0.5.0/docs/_reference/upgrading.md).

## Remove deprecated settings

```ruby
OpenUI::Rails.configure do |config|
  config.library_name = :chat        # remove: deprecated, no effect
  config.surface_id_param = :id      # remove: deprecated, no effect
end
```

Neither setting ever changed behavior. Using either one now reports a
deprecation through `OpenUI::Rails.deprecator`. Your application's deprecation
settings apply because the engine registers it in
`Rails.application.deprecators`. Both settings are removed in 1.0.

## Review action error handling

The endpoint used to return HTTP 422 with code `error` and an internal message
for a server-side gem error. It now returns HTTP 500 with code `error` and the
fixed message `action failed`, and writes the details to the server log. If
your JavaScript branched on that 422 status or displayed the message, branch on
the `error` code and show your own text. The handler may already have run, so
treat the outcome as unknown. Request errors keep their codes and statuses.

## Review stream producers

After a `stream_too_large` frame, `Bridge#envelopes`, `Broadcaster.broadcast`,
and the RubyLLM adapter stop reading the provider. If you push chunks from a
callback, stop your provider when `writer.terminated?` returns true. Later
pushes are ignored either way.

The RubyLLM adapter stops generation by raising out of RubyLLM's streaming
block. RubyLLM then adds no assistant message. If you persist chat history,
treat that turn like any other failed stream.

An exception from your `on_error` hook is now ignored, so the error frame is
still sent. Report failures from inside the hook if you need them.

## Review browser recovery

A paused surface emits `openui:snapshot-required` again when it reconnects,
including after a Turbo cache restoration. Keep your snapshot request
single-flight and discard responses for a disconnected surface; you can receive
the event more than once for one gap.

A surface without a stored `library_version` now rejects frames whose
`library_version` differs from the configured fingerprint, and reports
`library_version_mismatch`. Producers that set `library_version` from
`OpenUI::Rails.configuration.library_fingerprint` are unaffected.

`OpenUI::Rails::RuntimeAsset` is now marked internal. Configure assets through
the [configuration settings]({% link _getting_started/configuration.md %}).

## Plan a rollback

Storage, schema, and library files stay compatible with 0.5. Rolling back
restores the 422 response for server-side errors and the earlier stream and
recovery defects. Do not drop shared-store or business tables as part of a
rollback.

## Next Steps

* [What's New]({% link _getting_started/whats-new-in-0-9.md %}) - review the release scope.
* [Supported API]({% link _reference/supported-api.md %}) - review what 1.x keeps compatible.
