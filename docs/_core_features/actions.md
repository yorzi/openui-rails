---
layout: default
title: Server Actions
nav_order: 3
description: Route model-proposed actions through a Rails allowlist, authorization, validation, and replay protection.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to register an action and its argument schema.
* Which checks run before a handler.
* What confirmation and idempotency do and do not guarantee.

## Register an allowlisted action

A model-proposed action name never maps to a Ruby method by reflection. Only names registered in the host's action registry can run.

```ruby
OpenUI::Rails.actions.register(
  "orders.refresh",
  description: "Re-fetch an order",
  schema: { "orderId" => String },
  authorize: ->(invocation) {
    OrderPolicy.new(invocation.actor, invocation.args.fetch("orderId")).refresh?
  },
  handler: ->(invocation) {
    order = Order.find(invocation.args.fetch("orderId"))
    OrderSerializer.new(order).as_json
  }
)
```

The engine exposes the default endpoint at `/openui-rails/actions`. The install generator mounts the engine at `/openui-rails`. Adjust `actions_endpoint` if you mount it elsewhere.

Component `onAction` events and browser `Query()`/`Mutation()` calls use the same request body:

```json
{
  "action": "orders.refresh", "args": { "orderId": "42" },
  "surface_id": "support-42", "version": 3,
  "idempotency_key": "request-unique-key", "confirmed": false
}
```

The bridge maps the runtime's `{ type, params }` event to `action` and `args`. The browser includes the Rails CSRF token. Do not infer confirmation from model parameters or form state; collect it in trusted host UI.

## Checks before execution

The dispatcher parses the request, finds the registered action, validates arguments, checks any required confirmation, checks the surface revision, authorizes the invocation, and claims its idempotency key before calling the handler. A missing authorizer denies the request. A `surface_resolver` should resolve the submitted id inside the authenticated actor and tenant scope.

Set `confirmation: true` for an action that requires the host to submit `confirmed: true`. That value is a host-supplied acknowledgement, not cryptographic proof that a person approved the operation. For high-risk work, verify a signed, server-issued approval in the authorizer too.

An idempotency key is scoped to actor and tenant and binds the request arguments. A retry with the same completed request replays the stored result. Reuse with different arguments is rejected. The default store is process-local; it does not coordinate workers or survive restarts. This is not an exactly-once guarantee.

## Handle action errors

The dispatcher also publishes bounded outcome notifications. See
[Diagnostics and Recovery]({% link _advanced/diagnostics-and-recovery.md %}) for
the server payloads, browser event fields, and explicit recovery paths.

The endpoint returns JSON with an `error` object containing `code` and `message`. Use the code to choose host-owned recovery UI. The browser rejects authentication redirects and malformed or mismatched responses instead of reporting success.

| Code | HTTP status | Meaning |
| --- | --- | --- |
| `unknown_action` | 404 | The action is not registered. |
| `unauthorized` | 403 | Authorization is missing or denied, or the surface is inaccessible. |
| `stale_surface` | 409 | The surface revision has changed. |
| `replay` | 409 | The key is still pending or was reused for a different request. |
| `invalid_action` | 422 | The payload, arguments, or required confirmation are invalid. |
| `csrf_failed` | 422 | The authenticity token is invalid. |
| `error` | 500 | A server-side gem error, such as an unserializable result or an actor without a stable id. The message is always `action failed`; the server log has the details. The handler may already have run. |

The browser also reports `unauthorized` for a redirect and `invalid_response` for invalid endpoint responses through `openui:error`. A browser error event does not carry an HTTP status for these local checks. A tool call receives the handler's `value`; the `openui:action` event carries the full result.

## Continue a conversation

The pinned runtime emits `@ToAssistant` metadata beside its `params`. The
bridge adds it to the `continue_conversation` action's arguments:

```ruby
OpenUI::Rails.actions.register "continue_conversation",
  schema: OpenUI::Rails::Actions::Schema.define(
    required: { "message" => String },
    optional: { "context" => Object, "form_name" => String, "form_state" => Hash }
  ),
  handler: ->(invocation) { YourConversationFlow.call(invocation) }
```

`humanFriendlyMessage` becomes `message`, `formName` becomes `form_name`, and
`formState` becomes `form_state` when each field is present. Runtime metadata
takes precedence over same-named keys in `params`. Other action types and tool
arguments are unchanged. These are untrusted browser inputs. Bound and validate
their sizes and field names before persistence, and keep actor, tenant,
conversation lookup, and authorization on the server. The host handler owns
conversation history and the next response; the gem does not run an agent loop.

## Next Steps

* [Configuration]({% link _getting_started/configuration.md %}) - configure actor, surface, and global authorization.
* [Production Considerations]({% link _advanced/production.md %}) - choose a shared atomic idempotency store.
* [API Reference]({% link _reference/api-reference.md %}) - see dispatcher and registry classes.
