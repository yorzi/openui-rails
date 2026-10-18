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

## Checks before execution

The dispatcher parses the request, finds the registered action, validates arguments, checks any required confirmation, checks the surface revision, authorizes the invocation, and claims its idempotency key before calling the handler. A missing authorizer denies the request. A `surface_resolver` should resolve the submitted id inside the authenticated actor and tenant scope.

Set `confirmation: true` for an action that requires the host to submit `confirmed: true`. That value is a host-supplied acknowledgement, not cryptographic proof that a person approved the operation. For high-risk work, verify a signed, server-issued approval in the authorizer too.

An idempotency key is scoped to actor and tenant and binds the request arguments. A retry with the same completed request replays the stored result. Reuse with different arguments is rejected. The default store is process-local; it does not coordinate workers or survive restarts. This is not an exactly-once guarantee.

## Next Steps

* [Configuration]({% link _getting_started/configuration.md %}) - configure actor, surface, and global authorization.
* [Production Considerations]({% link _advanced/production.md %}) - choose a shared atomic idempotency store.
* [API Reference]({% link _reference/api-reference.md %}) - see dispatcher and registry classes.
