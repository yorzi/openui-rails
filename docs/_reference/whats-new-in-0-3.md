---
layout: default
title: What's New in 0.3
nav_order: 3
parent: Release History
description: Run a persisted support-ticket workflow with real rendering and scoped recovery in a Rails reference host.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to exercise the complete reference workflow without a provider.
* How to restore persisted stream metadata and continue a conversation.

Version `0.3.0` adds the reference host and persisted stream restoration.

## Run the reference workflow

```sh
bin/check-reference --runtime tmp/real-runtime
bin/check-reference --gem tmp/package/openui-rails-0.3.0.gem --runtime tmp/real-runtime
```

Fetch the checksum-locked runtime and build the gem first using
[Reference Workflow]({% link _getting_started/reference-workflow.md %}). The
reference host streams recorded output, renders a real `Query()`, persists a
private draft, continues a conversation, and closes a ticket through an
explicitly authorized `Mutation()`. It also recovers from a missing envelope
using the host's scoped snapshot endpoint.

## Restore canonical response state

```ruby
openui_surface(surface: { id: "ticket-42", message_id: "ticket-42-turn-2",
                          response: saved_response, next_sequence: 7,
                          completed: true }, initial_state: saved_state)
```

The host persists output, form state, message identity, and the next sequence.
See [Streaming]({% link _core_features/streaming.md %}) for watermark rules.

## Continue through the host

The bridge now forwards the official runtime's conversation message and form
metadata. Update strict `continue_conversation` schemas before upgrading.
The host still owns authorization, conversation history, and generating the
next response. Read [Server Actions]({% link _core_features/actions.md %}) for
the argument contract.

## Next Steps

* [Reference Workflow]({% link _getting_started/reference-workflow.md %}) - inspect the runnable host and its limits.
* [Upgrading]({% link _reference/upgrading.md %}) - review argument schema changes.
