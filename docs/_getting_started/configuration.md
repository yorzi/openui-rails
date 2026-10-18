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

After you create the matching prompt and manifest, call `OpenUI::Rails.configuration.validate!` from a task, console, or deployment check. Boot does not call it because the generator and runtime-fetch task must work before those files exist.

## Settings

| Setting | Default | What it controls |
| --- | --- | --- |
| `transport` | `:turbo` | A host preference. Build and connect a transport explicitly; this setting does not create a subscription. |
| `library_spec_path` | `nil` | Manifest generated from the exact browser library. Enables its fingerprint checks. |
| `prompt_path` | `nil` | Prompt generated from the same library revision. |
| `runtime_assets` | `:self_hosted` | Use vendored assets or configure explicit external URLs. |
| `local_runtime_path` | `"/openui"` | Public URL directory for self-hosted assets. |
| `runtime_version` | pinned `0.2.1` | Runtime version used by the fetch task and default asset URLs. |
| `runtime_url` | derived | Override the JavaScript URL. External and custom builds need an exact URL. |
| `runtime_integrity` | pinned for the default runtime | Subresource integrity value for a custom JavaScript file. |
| `runtime_stylesheet_url` | derived | Override the stylesheet URL; required for external assets. |
| `runtime_stylesheet_integrity` | pinned for the default runtime | Subresource integrity value for a custom stylesheet. |
| `actions_endpoint` | `"/openui-rails/actions"` | Must match the engine mount path in your routes. |
| `stream_byte_limit` | `1_048_576` | Maximum response bytes per message. |
| `pending_byte_limit` | `32_768` | Bytes buffered before a delta is emitted; cannot exceed the stream limit. |
| `idempotency_ttl` | `900` seconds | How long a claimed action key remains in the store. |
| `idempotency_store` | process-local memory store | Replace it with an atomic shared store when multiple workers must coordinate. |
| `idempotency_scope` | actor and tenant identity | Optional callable for stable custom actor or tenant identities. |
| `actor_resolver` | `current_user`, when available | Resolves the authenticated actor from the engine controller. |
| `surface_resolver` | `nil` | Resolves a surface within the actor's authorized scope. |
| `authorize_action` | `nil` | Global action authorizer. Missing authorization denies an action. |
| `on_error` | `nil` | Server-side stream error hook. Avoid logging credentials or unredacted provider input. |

`library_name` and `surface_id_param` are legacy metadata settings. They do not choose the runtime library or change the action request's `surface_id` key.

## Next Steps

* [Library and Prompt Contract]({% link _core_features/library-contract.md %}) - generate matching prompt and manifest files.
* [Runtime Assets]({% link _core_features/runtime-assets.md %}) - vendor the pinned browser bundle.
* [Production Considerations]({% link _advanced/production.md %}) - choose safe identity and replay boundaries.
