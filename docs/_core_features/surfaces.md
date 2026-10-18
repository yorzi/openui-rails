---
layout: default
title: Rendering Surfaces
nav_order: 1
description: Render the pinned OpenUI runtime in a Rails view from server-owned surface data.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which values a surface can carry.
* How to mount a response and include an accessible label.
* How the helper checks a configured library fingerprint.

## Render a surface in a view

A surface is the host-owned state that the browser renderer receives. Build one explicitly, pass a hash, or pass a record that exposes `id` and optional surface fields.

```ruby
@surface = OpenUI::Rails::Surface.new(
  id: "ticket-42",
  version: 3,
  library_version: OpenUI::Rails.configuration.library_fingerprint,
  response: 'root = TextContent("Ticket received")',
  context: { "status" => "open" }
)
```

Render it from an ERB view:

```erb
<%= openui_surface(surface: @surface, label: "Ticket response") %>
```

The helper emits an escaped `div` for the Stimulus mount. `label:` makes it a `region` landmark; a streaming mount also gets `aria-busy="true"` until the client receives a terminal event. The runtime stylesheet belongs in the layout head and is included once with `openui_stylesheet_tag`.

## Surface fields

| Field | Purpose |
| --- | --- |
| `id` | Stable opaque surface identifier. |
| `version` | Non-negative revision used to reject stale actions. Defaults to `0`. |
| `library_version` | Manifest fingerprint associated with the stored response. |
| `response` | OpenUI Lang text for the browser renderer. The gem does not parse it. |
| `context` | JSON-compatible initial state for the host and client. |
| `message_id` | Stream identity. Defaults to the surface id. |
| `streaming` | Whether the surface is currently receiving output. |

You can override mount-specific values with `stream:`, `dom_id:`, `initial_state:`, and `label:`. Hashes accept symbol or string keys. Host records can expose `id`, `version`, `library_version`, `response`, `context`, and `message_id`.

When `library_spec_path` is configured, the helper rejects a surface whose non-nil `library_version` differs from the configured manifest fingerprint. The browser compares the loaded library with the same fingerprint before mounting. Without a manifest, the gem cannot verify that a prompt, stored response, and runtime library belong together.

## Next Steps

* [Library and Prompt Contract]({% link _core_features/library-contract.md %}) - generate the manifest and prompt from one library.
* [Runtime Assets]({% link _core_features/runtime-assets.md %}) - prepare JavaScript and CSS.
* [Streaming Responses]({% link _core_features/streaming.md %}) - update a mounted surface incrementally.
