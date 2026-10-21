---
layout: default
title: Diagnostics and Recovery
nav_order: 5
description: Observe bounded server outcomes and provide explicit host-owned recovery for browser failures.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which server notification fields you can collect without application content.
* Which browser events the bridge emits and when they occur.
* How to offer fallback, snapshot recovery, and a fresh sign-in without retrying mutations.

## Observe server outcomes

Subscribe once in your application's initializer:

```ruby
ActiveSupport::Notifications.subscribe("action.openui_rails") do |event|
  Rails.logger.info(event.payload.to_json)
end
```

The dispatcher publishes one `action.openui_rails` event when a call returns or
raises. The writer publishes one `stream.openui_rails` event when it creates a
terminal envelope. Repeated `finish` or `error_for` calls emit no extra event.
These notifications carry fixed metadata, without raw exception information.
An exception in a subscriber does not change an action result or mask the
application's original exception. Other subscribers should not depend on a
failing subscriber running successfully.

| Event | Payload |
| --- | --- |
| `action.openui_rails` | `outcome`, `code`, `replayed`, `duration_ms` |
| `stream.openui_rails` | `outcome`, `code`, `sequence`, `bytes`, `duration_ms` |

Action outcomes are `succeeded`, `replayed`, `rejected` before handler execution,
or `failed` during execution or storage. Unexpected Ruby errors are `failed`
with `internal_error`; domain errors use the documented
[action error codes]({% link _core_features/actions.md %}#handle-action-errors).
Successful calls have a null code. `replayed` is a boolean.

Stream outcomes are `completed`, `failed`, or `cancelled`. Codes are null on
completion, otherwise an envelope error code. `sequence` is the terminal frame's
sequence, starting at zero. `bytes` counts received content, including the chunk
that exceeds the byte limit. It is not a response body or token count.

Use `payload[:duration_ms]` for elapsed time. It uses a monotonic clock from call
entry or writer creation to publication. Active Support's `event.duration`
measures only notification delivery because application code is not executed
inside its instrumentation block.

These events do not report middleware rejection, CSRF checks before the
dispatcher, transport delivery, or an abandoned writer. A terminal event proves
the writer created a frame, not that a browser received it. Notification fields
exclude action names, surface and message IDs, identities, arguments, form state,
results, prompts, response text, credentials, and exception objects or messages.
The separate, optional `on_error` callback still receives a raw exception; review
your own logging before enabling it.

## Listen to browser events

Browser events bubble from the surface element. Add your listeners before the
surface connects, for example through a parent Stimulus controller's `data-action`.
Do not collect their complete payloads as telemetry: state, results, and error
messages can contain application data. Use error codes for decisions and show
messages as text rather than HTML.

| Event | `detail` fields | Meaning |
| --- | --- | --- |
| `openui:ready` | `surfaceId` | Runtime loaded, library verified, and initial rendering scheduled for this connection. |
| `openui:action` | `surfaceId`, `result` | A matching successful action response, including its replay status. |
| `openui:state` | `surfaceId`, `state` | Form state offered to the host for persistence. |
| `openui:error` | `surfaceId`, `code`, `message` | Renderer, stream, runtime, or action failure. |
| `openui:snapshot-required` | `surfaceId`, `sequence` | A gap paused deltas; sequence is the next expected watermark. A paused surface emits it again when it reconnects, including after a Turbo cache restoration. |
| `openui:snapshot-applied` | `surfaceId`, `sequence` | A snapshot passed library, sequence, and size checks; sequence is the accepted frame's watermark. |

Ready and snapshot-applied events do not promise that React has painted or that
the generated source is valid. Renderer errors can follow them. Rejected and
stale snapshots emit no snapshot-applied event. `openui:envelope` is a transport
input, not an outcome event; see [Streaming]({% link _core_features/streaming.md %}).

Runtime failures use `runtime_load_failed`. Library checks use
`library_version_mismatch`. Local stream validation uses `invalid_envelope` and
`stream_too_large`; parse failures use `renderer_error`. Invalid action responses
use `invalid_response`; fetch failures use `network_error`, and an active
cancelled request uses `request_cancelled`. An unsuccessful JSON action response
without a code uses `action_failed`. The endpoint's own codes and normalized
provider errors are retained. Empty renderer error arrays emit no error event.

## Choose an explicit recovery path

Keep ordinary HTML record information and recovery links outside the island.
This remains usable when the renderer or JavaScript cannot load. Use native
links and buttons with visible names, a status region for progress, and an alert
for failures. A host can disable interaction with an outdated island using
`inert` while leaving recovery controls reachable.

| Failure | Host response |
| --- | --- |
| Runtime load or library mismatch | Show ordinary HTML details and an explicit page reload after setup is corrected. |
| Provider rejection, stream failure, or byte limit | Stop the busy indicator, retain canonical host data, and offer reload or host-controlled regeneration. |
| Sequence gap | Fetch one scoped, authorized snapshot; allow an explicit read retry if it fails. |
| `stale_surface` | Reload canonical state before offering another mutation. |
| Authentication expiry or `csrf_failed` | Start a fresh sign-in and reload the surface; do not replay the old submission. |
| Network, cancellation, or an invalid action response | Treat the business outcome as unknown and reconcile through canonical state or a receipt. |

A failed or cancelled fetch does not prove that the handler did nothing. Never
automatically retry a mutation whose outcome is unknown. Idempotency tokens and
business receipts still have the limits described in
[Shared Idempotency Storage]({% link _advanced/shared-idempotency.md %}).

The bridge aborts action requests on disconnect and suppresses their late
outcomes, including after reconnect. Shared runtime loading can continue for
other surfaces. The host must also abort its own streams and snapshot requests,
discard old async responses, and remove listeners before Turbo caches a page.

## Run the reference recovery paths

The [Reference Workflow]({% link _getting_started/reference-workflow.md %}) uses
ordinary HTML ticket details, an explicit reload link, and a sign-in link. Its
single-flight snapshot request is scoped by user and tenant. It clears recovery
feedback only after a snapshot-applied event, and restores interactivity after
runtime readiness. Reload and sign-in never automatically repeat the old action.
The example uses recorded generation, not a live-provider reliability claim.

## Next Steps

* [Server Actions]({% link _core_features/actions.md %}) - enforce authorization and inspect error codes.
* [Streaming]({% link _core_features/streaming.md %}) - preserve sequencing and canonical snapshots.
* [Production Considerations]({% link _advanced/production.md %}) - review host responsibilities.
