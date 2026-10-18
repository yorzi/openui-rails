---
layout: default
title: How OpenUI Rails Works
nav_order: 2
description: See how Rails views, the browser runtime, streams, and server actions fit together.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which public objects and helpers your Rails app calls.
* Which responsibilities stay in the host application.
* Where to find the guide for each integration layer.

## The public API

A Rails view calls `openui_surface` with a `Surface`, a hash, or a host record. The helper serializes surface data into escaped DOM attributes for the `openui` Stimulus controller.

```ruby
surface = OpenUI::Rails::Surface.new(
  id: "ticket-42",
  version: 3,
  response: 'root = TextContent("Ticket received")'
)
```

The host sends provider output through `OpenUI::Rails::Stream::Bridge` or `Stream::Broadcaster`. The bridge emits ordered envelopes; a transport delivers them to the page.

For writes, `OpenUI::Rails.actions.register` declares callable action names. The engine endpoint validates the request, resolves the surface, checks authorization and idempotency, then calls the registered handler.

## How the parts fit together

* **Rails host:** owns users, tenant scoping, records, provider credentials, persistence, subscriptions, and snapshot recovery.
* **Gem:** mounts the engine, renders safe data attributes, checks the library manifest, sequences stream envelopes, and runs the action gates.
* **Browser runtime:** parses and renders OpenUI Lang and emits action, state, error, and snapshot-required events.

The gem does not implement the OpenUI Lang parser or a persistence layer. A Rails surface is an adapter around host-owned state. The host also chooses how a stream reaches the page; a configured transport is not an automatic subscription.

## Next Steps

* [Rendering Surfaces]({% link _core_features/surfaces.md %}) - mount a response in a Rails view.
* [Streaming Responses]({% link _core_features/streaming.md %}) - sequence provider output.
* [Server Actions]({% link _core_features/actions.md %}) - authorize model-proposed work.
* [Production Considerations]({% link _advanced/production.md %}) - review identity and replay boundaries.
* [Roadmap on GitHub](https://github.com/yorzi/openui-rails/blob/main/ROADMAP.md) - review proposed work toward 1.0.
