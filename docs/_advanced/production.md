---
layout: default
title: Production Considerations
nav_order: 3
description: Scope actions and replay protection to authenticated actors, tenants, and shared storage.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Where the host must enforce authentication and tenant scope.
* Why the default idempotency store is not sufficient for multiple workers.
* Which delivery and provider guarantees the gem does not provide.

## Scope every action to host identity

The engine inherits the host application's controller and authentication filters. Configure an actor resolver when the host does not expose `current_user`. Resolve a submitted surface through a tenant-scoped query, and use an authorizer that checks the specific operation on that record.

```ruby
config.actor_resolver = ->(controller) { controller.current_user }

config.surface_resolver = ->(surface_id, actor:, **) {
  actor&.surfaces&.find_by(id: surface_id)
}

config.authorize_action = ->(invocation) {
  OrderPolicy.new(invocation.actor, invocation.surface).refresh?
}
```

A nil surface resolution denies the action. If you do not use a resolver, your authorizer must own surface access and revision checks. Do not trust a client-provided actor or tenant identifier.

## Use shared atomic replay storage

The default idempotency store is process-local memory. It cannot coordinate separate workers and is lost on restart. For a multi-process app using SQLite, install the opt-in table described in [Shared Idempotency Storage]({% link _advanced/shared-idempotency.md %}) and configure it:

```ruby
config.idempotency_store = OpenUI::Rails::Actions::Idempotency::ActiveRecordStore.new
config.idempotency_ttl = 900
```

A store must atomically distinguish a new claim, an in-progress claim, and a completed replay. A handler failure leaves its claim pending until expiry because side effects may already have happened. A handler that outlives its TTL can overlap a later claim. Enforce business-level uniqueness or transactions for irreversible operations. Idempotency reduces duplicate execution within its scope; it is not an exactly-once guarantee.

## Plan for delivery and recovery

Action Cable and Turbo Streams do not guarantee ordered or durable delivery. Persist canonical response state in the host and serve an authorized snapshot when the browser emits `openui:snapshot-required`. Keep provider credentials on the server and avoid logging unredacted requests or response context.

`confirmed: true` is an application-level acknowledgement, not proof of human consent. For high-impact operations, require a signed approval or another server-verified control in the authorizer.

## Review assets and content policy

Self-hosting is the default. Keep exact runtime pins and integrity hashes for JavaScript and CSS; see [Runtime Assets]({% link _core_features/runtime-assets.md %}). The browser bundle runs as trusted page code, not in a sandbox. Review its full transitive license notices before redistributing it.

The bridge adds no inline scripts. Your script policy must permit the runtime you serve. The upstream renderer uses inline styles and inserts a loading `<style>` element, so validate your `style-src` policy against the actual bundle. Script integrity alone does not establish strict-CSP compatibility.

The Support Desk reference verifies an enforced `script-src 'self'` policy with
per-request nonces for Rails importmap tags. It does not allow `unsafe-eval` or
untrusted inline scripts. Include `csp_meta_tag` in the layout when using Turbo.
Its nonce generator applies only when you explicitly load the reference host.
Existing applications must retain their own policy and nonce configuration.

The reference permits `style-src 'self' 'unsafe-inline'` because the pinned
renderer requires inline styles. This is a tested script policy, not a claim
that the runtime works under an inline-style ban. It covers the reference's
forms and actions; qualify charts, images, external URLs, and other components
against your application's policy separately.

## Verify keyboard access and fallback

Give each surface a meaningful `label:` and keep recovery controls outside the
renderer. The reference tests accessible form names, Tab navigation, Enter
activation, visible error and status regions, and 390px layout. A blocked runtime
still leaves native reload and recovery controls reachable.

These checks do not establish complete WCAG conformance or screen-reader
announcements. Review your generated components and content with your target
assistive technology. Model output does not replace that application review.

## Next Steps

* [Server Actions]({% link _core_features/actions.md %}) - register and authorize each callable operation.
* [Streaming Responses]({% link _core_features/streaming.md %}) - implement host-owned snapshot recovery.
* [Configuration]({% link _getting_started/configuration.md %}) - review all defaults.
