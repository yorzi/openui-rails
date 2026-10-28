---
layout: default
title: What's New in 0.9
nav_order: 5
description: Freeze the candidate API for 1.0 and fix stream, recovery, and action error defects found while qualifying it.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which APIs the 1.0 compatibility commitment covers.
* How the stabilization follow-up improves the demo and host checks.
* Which stream and browser recovery defects 0.9 fixes.
* Which settings are deprecated and what the action endpoint now returns for server errors.

{% unless site.released %}Version `{{ site.version }}` is an unpublished stabilization candidate.
The stable site stays on the latest published release.{% endunless %}

## Run the demo and qualify a host

```sh
bin/demo --runtime tmp/real-runtime --port 3000
```

The stabilization follow-up adds a disposable demo command and stronger host,
upgrade, CSP, and keyboard checks. It keeps the same gem API and runtime pin.
See [Reference Workflow]({% link _getting_started/reference-workflow.md %}) for
the checkout-only demo and
[Production Considerations]({% link _advanced/production.md %}) for the tested policy.

The demo uses synthetic accounts and recorded generation. Its foreground server
binds loopback and removes its temporary host when stopped. This command belongs
to the development checkout; fetch the pinned runtime before running it.

## Know the supported boundary

Version 0.9 adds no features. It names the classes, settings, events, and wire
formats that 1.x keeps compatible, and the policy for changing the pinned
runtime. Read [Supported API]({% link _reference/supported-api.md %}) before you
depend on a class or method that a guide does not show.

## Stop oversized generation

```ruby
writer = bridge.writer
provider.stream do |chunk|
  writer.push(chunk).each { |envelope| transport.broadcast(envelope) }
  break if writer.terminated?
end
```

A response that passes `stream_byte_limit` still ends with `stream_too_large`.
Now `Bridge#envelopes`, `Broadcaster.broadcast`, and the RubyLLM adapter stop
reading the provider at that point instead of consuming the rest of the
response. For a callback-based provider, check `Writer#terminated?` yourself.
An exception from your `on_error` hook no longer suppresses the error frame.

## Recover restored surfaces

A surface paused for a snapshot emits `openui:snapshot-required` again when it
reconnects, including after a Turbo cache restoration. A surface that stores no
`library_version` checks stream frames against the configured library
fingerprint. The [Server Actions]({% link _core_features/actions.md %}#open-a-url)
guide shows how to allowlist the default library's `@OpenUrl` step.

## Review endpoint errors and deprecations

Server-side gem errors, such as an unserializable result, return HTTP 500 with
code `error` and the message `action failed`. `config.library_name` and
`config.surface_id_param` report a deprecation and are removed in 1.0.

## Next Steps

* [Upgrading]({% link _reference/upgrading.md %}) - update from 0.5.
* [Supported API]({% link _reference/supported-api.md %}) - review the compatibility boundary.
