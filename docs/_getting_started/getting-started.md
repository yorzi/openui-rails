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

The generator does not download JavaScript assets or create a library prompt and manifest. Those steps are explicit so you can review and commit their inputs. See [Configuration]({% link _getting_started/configuration.md %}) for application settings.

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

The helper outputs a mount element for the Stimulus controller. It does not render the response itself. Add the pinned runtime stylesheet once to the host layout, fetch the self-hosted runtime, and register the gem's Stimulus controllers as described in [Runtime Assets]({% link _core_features/runtime-assets.md %}). OpenUI Lang is rendered by the browser runtime.

## Next Steps

* [How OpenUI Rails Works]({% link _getting_started/overview.md %}) - understand the boundary between the gem and your host app.
* [Configuration]({% link _getting_started/configuration.md %}) - set library paths, authorization, and stream limits.
* [Rendering Surfaces]({% link _core_features/surfaces.md %}) - choose surface attributes and accessibility labels.
