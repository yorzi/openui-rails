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

Restore `response`, `message_id`, `next_sequence`, and `completed` together
when you persist a stream. This prevents late frames from being applied again
after a reload. See [Streaming Responses]({% link _core_features/streaming.md %})
for the watermark contract. Completed surfaces cannot also be streaming.

| Field | Purpose |
| --- | --- |
| `id` | Stable opaque surface identifier. |
| `version` | Non-negative revision used to reject stale actions. Defaults to `0`. |
| `library_version` | Manifest fingerprint associated with the stored response. |
| `response` | OpenUI Lang text for the browser renderer. The gem does not parse it. |
| `context` | JSON-compatible initial state for the host and client. |
| `message_id` | Stream identity. Defaults to the surface id. |
| `streaming` | Whether the surface is currently receiving output. |
| `next_sequence` | Next expected envelope after persisted output. Defaults to `0`. |
| `completed` | Whether non-snapshot updates for this message are terminal. Defaults to `false`. |

You can override mount-specific values with `stream:`, `dom_id:`, `initial_state:`, and `label:`. Hashes accept symbol or string keys. Host records can expose `id`, `version`, `library_version`, `response`, `context`, `message_id`, `next_sequence`, and `completed`.

When `library_spec_path` is configured, the helper rejects a surface whose non-nil `library_version` differs from the configured manifest fingerprint. The browser compares the loaded library with the same fingerprint before mounting. Without a manifest, the gem cannot verify that a prompt, stored response, and runtime library belong together.

## Handle browser events

Listen on the surface element for bubbling events and provide host-owned UI or persistence as needed. The controller receives `openui:envelope`; it emits these events:

| Event | Detail fields | Host responsibility |
| --- | --- | --- |
| `openui:action` | `surfaceId`, `result` | Update host UI after a successful action or tool call. |
| `openui:state` | `surfaceId`, `state` | Persist form state if it should survive a reload. |
| `openui:error` | `surfaceId`, `code`, `message` | Show a fallback or recovery control. Some upstream errors have no code. |
| `openui:snapshot-required` | `surfaceId`, `sequence` | Fetch and dispatch an authorized snapshot after a sequence gap. |

The bridge does not provide fallback UI, snapshot endpoints, or an automatic reconnection policy. A library mismatch reports `library_version_mismatch` and prevents mounting. See [Streaming Responses]({% link _core_features/streaming.md %}) for recovery behavior.

`label:` and `aria-busy` describe the mount, not the accessibility of every generated component. Automated tests cover named regions, busy states, and keyboard activation. A human screen-reader audit of generated content has not been performed.

## Next Steps

* [Library and Prompt Contract]({% link _core_features/library-contract.md %}) - generate the manifest and prompt from one library.
* [Runtime Assets]({% link _core_features/runtime-assets.md %}) - prepare JavaScript and CSS.
* [Streaming Responses]({% link _core_features/streaming.md %}) - update a mounted surface incrementally.
* [Stored Messages]({% link _core_features/messages.md %}) - keep response content and form context together.
