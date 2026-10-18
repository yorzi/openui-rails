---
layout: default
title: Streaming Transports
nav_order: 1
description: Deliver OpenUI stream events through Turbo Streams, Action Cable, or a host transport.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to bind a stream bridge to a transport.
* When to use Turbo Streams or Action Cable.
* Which subscription and authorization responsibilities remain in the host.

## Bind a bridge to a transport

`Stream::Broadcaster` accepts any transport object that implements `broadcast(envelope)`:

```ruby
transport = OpenUI::Rails::Stream::Transports.build(
  :action_cable,
  stream_name: "openui:surface:#{surface.id}"
)

broadcaster = OpenUI::Rails::Stream::Broadcaster.new(
  transport: transport,
  message_id: surface.id,
  library_version: OpenUI::Rails.configuration.library_fingerprint
)

chat.complete { |chunk| broadcaster.push(chunk.content) }
broadcaster.finish
```

The gem sequences and size-limits frames before transport delivery. Delivery can be delayed, duplicated, reordered, or lost. The browser uses sequence numbers and requests a snapshot after a gap.

## Choose a transport

* **Turbo Streams:** build with `:turbo`, pass the host stream name and a target already present in the DOM. The helper appends a short-lived `openui-envelope` element, whose Stimulus controller dispatches the envelope event. The host needs `turbo-rails`, a Turbo subscription, and an inbox outside the renderer-owned subtree.
* **Action Cable:** build with `:action_cable` and a host-chosen stream name. The transport broadcasts envelope hashes. Your channel must authenticate and authorize the subscription, and browser code must re-emit received data as a bubbling `openui:envelope` event.
* **Memory:** build with `:memory` in tests or examples. It stores envelopes in the current process.

`config.transport` records the host's preference; it does not create a subscription or route a job automatically. Use `:none` when you manage delivery entirely in host code.

## Next Steps

* [Streaming Responses]({% link _core_features/streaming.md %}) - understand frame order and snapshot recovery.
* [Production Considerations]({% link _advanced/production.md %}) - scope subscriptions and persist canonical responses.
* [API Reference]({% link _reference/api-reference.md %}) - see the transport and broadcaster APIs.
