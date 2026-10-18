---
layout: default
title: Streaming Responses
nav_order: 2
description: Stream ordered OpenUI Lang deltas and recover the rendered surface from a host-owned snapshot.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to convert provider chunks into stream envelopes.
* What each envelope sequence number means.
* What the host must do when the browser requests snapshot recovery.

## Convert chunks to envelopes

Use `Stream::Bridge` when the provider yields chunks and your host chooses delivery:

```ruby
transport = OpenUI::Rails::Stream::Transports.build(:memory)

OpenUI::Rails::Stream::Broadcaster.broadcast(
  ["root = ", 'TextContent("Ticket received")'],
  transport: transport,
  message_id: "ticket-42",
  library_version: OpenUI::Rails.configuration.library_fingerprint
)

transport.to_a.map(&:to_h)
```

The broadcaster emits `openui.delta`, then `openui.completed` when the source finishes. Sequence numbers start at zero for each message. Small chunks are buffered until `pending_byte_limit` is reached or the writer finishes; the default flush threshold is 32 KiB. The whole message is limited to 1 MiB by default.

For callback-based providers, create a writer and publish the envelopes returned by `push` and `finish`. `Stream::Broadcaster` combines the same writer with any object that responds to `broadcast(envelope)`.

## Envelope types

| Type | Meaning |
| --- | --- |
| `openui.delta` | Append this response fragment at the indicated sequence. |
| `openui.snapshot` | Replace the current response with an authoritative full response. |
| `openui.completed` | Mark the stream complete and clear the busy state. |
| `openui.error` | Stop the stream with a structured error code. |

The bridge orders its own frames but cannot guarantee that Action Cable or Turbo delivers them in order or at all. The browser ignores duplicates and pauses deltas after a sequence gap. It then emits `openui:snapshot-required`.

## Implement snapshot recovery in the host

The gem does not persist responses, provide a snapshot endpoint, or decide who can read a snapshot. The `openui:snapshot-required` event includes the sequence the client expects. Your host should load the current response through an authorized path, create an `openui.snapshot` envelope with a sequence the client accepts, and dispatch it to the page. Use the same surface and tenant checks as the action endpoint.

## Next Steps

* [Streaming Transports]({% link _advanced/transports.md %}) - deliver envelopes using Turbo Streams or Action Cable.
* [Server Actions]({% link _core_features/actions.md %}) - handle actions emitted by the rendered surface.
* [Production Considerations]({% link _advanced/production.md %}) - review limits, errors, and persistence ownership.
