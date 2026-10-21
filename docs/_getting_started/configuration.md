---
layout: default
title: Configuration
nav_order: 3
description: Set the library files, runtime assets, action authorization, and stream limits for a Rails app.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to configure OpenUI Rails in one initializer.
* Which settings matter for the library, assets, actions, and streaming.
* How to validate the configured manifest and prompt files.

## Configure the application

The install generator creates `config/initializers/openui.rb`. A typical host configuration looks like this:

```ruby
OpenUI::Rails.configure do |config|
  config.transport = :turbo
  config.library_spec_path = Rails.root.join("config/openui/library.spec.json")
  config.prompt_path = Rails.root.join("config/openui/library.prompt.txt")
  config.runtime_assets = :self_hosted

  config.actor_resolver = ->(controller) { controller.current_user }
  config.surface_resolver = ->(surface_id, actor:, **) {
    actor&.surfaces&.find_by(id: surface_id)
  }
  config.authorize_action = ->(invocation) { invocation.actor.present? }
end
```

The example is only a starting point. Replace the actor and surface lookup with your authentication and tenant-scoping rules. Actions are denied when no per-action or global authorizer is configured.

After you create the matching prompt and manifest, call `OpenUI::Rails.configuration.validate!` from a task, console, or deployment check. Boot does not call it because the generator and runtime-fetch task must work before those files exist. For a local report that also checks assets and routes, use [Setup Diagnostics]({% link _getting_started/setup-diagnostics.md %}).

## Settings

| Setting | Default | What it controls |
| --- | --- | --- |
| `transport` | `:turbo` | A host preference. Build and connect a transport explicitly; this setting does not create a subscription. |
| `library_spec_path` | `nil` | Manifest generated from the exact browser library. Enables its fingerprint checks. |
| `prompt_path` | `nil` | Prompt generated from the same library revision. |
| `runtime_assets` | `:self_hosted` | Use vendored assets or configure explicit external URLs. |
| `local_runtime_path` | `"/openui"` | Public URL directory for self-hosted assets. |
| `runtime_version` | pinned `{{ site.compatibility.browser_runtime }}` | Fetch accepts only the checksum-locked version; other versions are unverified. |
| `runtime_url` | derived | Override the JavaScript URL. External and custom builds need an exact URL. |
| `runtime_integrity` | pinned for the default runtime | Subresource integrity value for a custom JavaScript file. |
| `runtime_stylesheet_url` | derived | Override the stylesheet URL; required for external assets. |
| `runtime_stylesheet_integrity` | pinned for the default runtime | Subresource integrity value for a custom stylesheet. |
| `actions_endpoint` | `"/openui-rails/actions"` | Must match the engine mount path in your routes. |
| `stream_byte_limit` | `1_048_576` | Maximum response bytes per message. |
| `pending_byte_limit` | `32_768` | Bytes buffered before a delta is emitted; cannot exceed the stream limit. There is no timer-based flush. |
| `idempotency_ttl` | `900` seconds | How long a claimed action key remains in the store. |
| `idempotency_store` | process-local memory store | Replace it with an atomic shared store when multiple workers must coordinate. |
| `idempotency_scope` | actor and tenant identity | Optional callable for stable custom actor or tenant identities. |
| `actor_resolver` | `current_user`, when available | Resolves the authenticated actor from the engine controller. |
| `surface_resolver` | `nil` | Resolves a surface within the actor's authorized scope. |
| `authorize_action` | `nil` | Global action authorizer. Missing authorization denies an action. |
| `on_error` | `nil` | Server-side stream error hook, called with the error and `message_id:`. An exception it raises is ignored so the error frame is still sent. Avoid logging credentials or unredacted provider input. |
| `action_registry` | lazy `Actions::Registry` | Allowlisted action definitions. Per-action `authorize:` takes precedence over the global authorizer. |

`library_name` and `surface_id_param` are legacy metadata settings. They do not choose the runtime library or change the action request's `surface_id` key.

## Shared idempotency-store contract

Use a shared atomic store when separate processes can handle the same action. The dispatcher supplies a SHA-256 key scoped to trusted actor and tenant identity, plus a digest that binds the action, surface, version, arguments, and confirmation flag.

The optional [Active Record store]({% link _advanced/shared-idempotency.md %}) implements this contract on SQLite. To provide another adapter, implement these two methods:

```ruby
claim(key, ttl:, digest:)
# => [:claimed, nil, digest, claim_token]      # this request owns execution
# => [:pending, nil, stored_digest, token]    # execution is in progress
# => [:replay, result, stored_digest, token]  # completed, including nil/false

record(key, result, claim_token: token)
```

Make `claim` atomic and assign a unique token to each new claim. Ignore `record` calls whose token has expired or no longer owns the key. Distinguish completed `nil` and `false` results from pending claims.

The default identity is `[class, id]` for records and `[class, value]` for scalar identities. Unsupported identity objects require `idempotency_scope`. Derive that scope from trusted server state, never from client-supplied actor or tenant IDs. If tenant identity is not part of the actor identity, include the host's trusted tenant in a custom scope.

A failed handler leaves a pending claim until expiry because side effects may already have happened. A handler that outlives its TTL can overlap a later claim. Process-local memory cannot coordinate workers or survive restarts. Keep business-level uniqueness and transactions around irreversible operations; this contract does not guarantee exactly-once execution.

## Next Steps

* [Library and Prompt Contract]({% link _core_features/library-contract.md %}) - generate matching prompt and manifest files.
* [Runtime Assets]({% link _core_features/runtime-assets.md %}) - vendor the pinned browser bundle.
* [Production Considerations]({% link _advanced/production.md %}) - choose safe identity and replay boundaries.
