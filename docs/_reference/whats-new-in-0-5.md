---
layout: default
title: What's New in 0.5
nav_order: 5
parent: Release History
description: Observe action and stream outcomes and recover failed interfaces through host-owned controls.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to subscribe to content-free server notifications.
* How browser events support fallback, session recovery, and snapshot recovery.
* Which failures require an explicit reload rather than another mutation.

## Observe bounded outcomes

```ruby
ActiveSupport::Notifications.subscribe("action.openui_rails") do |event|
  Rails.logger.info(event.payload.to_json)
end
```

Action outcomes report success, replay, rejection, or failure. Stream outcomes
report completion, failure, or cancellation. Neither includes arguments,
results, prompts, credentials, identities, or raw exceptions. Subscriber errors
do not change the operation's result. Read
[Diagnostics and Recovery]({% link _advanced/diagnostics-and-recovery.md %}) for
the payloads, timing boundaries, browser events, and recovery recipes.

## Keep recovery in the host

The support-desk reference keeps ordinary HTML ticket details and reload controls
outside the renderer. It demonstrates scoped snapshot recovery, a fresh sign-in,
keyboard access, and Turbo restoration. It never automatically retries a
mutation after an unknown outcome. A late response from a disconnected action
cannot report success into a new connection.

## Next Steps

* [Upgrading]({% link _reference/upgrading.md %}) - review compatibility changes.
* [Reference Workflow]({% link _getting_started/reference-workflow.md %}) - run the packaged example.
