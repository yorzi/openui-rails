---
layout: default
title: RubyLLM Adapter
nav_order: 2
description: Bridge RubyLLM chat completion events into the OpenUI Rails stream contract.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to pass a RubyLLM chat through the optional adapter.
* How the adapter applies the generated library instruction and returns envelopes.
* Which RubyLLM version this integration has been verified against.

## Stream a RubyLLM chat

RubyLLM is optional. Add it to the host app separately, configure its provider credentials through RubyLLM, and build a chat using the host's normal RubyLLM setup.

```ruby
transport = OpenUI::Rails::Stream::Transports.build(
  :action_cable,
  stream_name: "openui:surface:#{surface.id}"
)

OpenUI::Rails::Adapters::RubyLLM.stream(
  chat: chat,
  question: "Summarize this ticket",
  surface_id: surface.id
) do |envelope|
  transport.broadcast(envelope)
end
```

The default `:complete` strategy adds the question as a user message and calls `complete` with a block. The adapter loads the system instruction from the configured prompt and manifest, passes it through `with_instructions` when available, and normalizes string chunks or chunks with `content`. Choose `strategy: :ask` if the host uses RubyLLM's `ask` API.

The adapter uses the configured byte limits and emits ordered `Stream::Envelope` objects. It converts provider failures into structured error frames without including the provider's error text. Exceptions raised by your envelope consumer propagate to the host.

## Compatibility boundary

The repository verifies RubyLLM `2.1.1` with deterministic OpenAI chat-completions SSE. Other versions and providers are not guaranteed by that check. The adapter does not make RubyLLM a gem dependency and does not configure provider credentials.

## Next Steps

* [Library and Prompt Contract]({% link _core_features/library-contract.md %}) - configure the system instruction source.
* [Streaming Responses]({% link _core_features/streaming.md %}) - understand the emitted envelope contract.
* [Production Considerations]({% link _advanced/production.md %}) - handle provider, persistence, and retry boundaries.
