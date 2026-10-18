---
layout: default
title: Getting Started
nav_order: 1
description: Install OpenUI Rails, prepare its browser runtime, and render your first server-owned surface.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which Ruby and Rails versions the gem supports.
* How to install the engine and prepare the browser runtime.
* How to render an OpenUI Lang response from a Rails view.

## Installation

```sh
{% if site.docs_unreleased %}bundle add openui-rails --git https://github.com/yorzi/openui-rails --branch main{% else %}bundle add openui-rails --version {{ site.version }}{% endif %}
bin/rails generate openui:install
```

OpenUI Rails supports Ruby 3.2 or newer and Rails 8.0 or newer, below Rails 9. The generator writes an initializer and `config/openui/README.md`, then mounts the engine at `/openui-rails` when the host has a routes file.

The generator does not download JavaScript assets or create a library prompt and manifest. Complete these steps before rendering:

1. Fetch the pinned runtime, include its stylesheet, and register the Stimulus controllers using [Runtime Assets]({% link _core_features/runtime-assets.md %}).
2. Run `bin/rails openui:library:prepare` for the default chat library. See [Library and Prompt Contract]({% link _core_features/library-contract.md %}) for custom libraries.
3. Run `bin/rails openui:doctor` to inspect local setup, then verify rendering in a browser. See [Setup Diagnostics]({% link _getting_started/setup-diagnostics.md %}) for the report's limits and [Configuration]({% link _getting_started/configuration.md %}) for application settings.

## Supported versions

The gem uses exact OpenUI runtime and CLI pins. The CI workflow defines the tested Ruby and Rails combinations; a dependency range alone does not establish compatibility with future releases.

| Component | Supported or verified scope |
| --- | --- |
| Ruby | Requires 3.2 or newer; CI covers 3.2, 3.3, and 3.4. |
| Rails | Requires 8.0 or newer, below 9.0; CI covers 8.0 and 8.1. |
| Browser runtime | `@openuidev/browser-bundle` {{ site.compatibility.browser_runtime }}, checksum-locked. |
| Custom-library CLI | `@openuidev/cli` {{ site.compatibility.cli }}. |
| RubyLLM | Optional; {{ site.compatibility.ruby_llm }} is verified with real SSE parsing and mocked HTTP. |

On Rails 8.0, constrain `json` to `< 3`. Its ActiveSupport and integration helpers pass `quirks_mode:` to `JSON.generate`, which json 3.1 removed. Rails 8.1 no longer passes that keyword. The engine expects a full-stack host controller; API-only authentication and CSRF integration are not qualified by this release.

## Render a surface

Create a surface in a controller or use a host record that exposes `id` and optionally surface fields:

```ruby
@surface = OpenUI::Rails::Surface.new(
  id: "support-42",
  response: 'root = TextContent("How can I help?")'
)
```

Render the mount in a view:

```erb
<%= openui_surface(surface: @surface, label: "Support") %>
```

The helper outputs a mount element for the Stimulus controller. OpenUI Lang is rendered by the browser runtime. Before enabling actions, configure scoped surface lookup and authorization using [Server Actions]({% link _core_features/actions.md %}).

## Next Steps

* [How OpenUI Rails Works]({% link _getting_started/overview.md %}) - understand the boundary between the gem and your host app.
* [Configuration]({% link _getting_started/configuration.md %}) - set library paths, authorization, and stream limits.
* [Rendering Surfaces]({% link _core_features/surfaces.md %}) - choose surface attributes and accessibility labels.
