---
layout: default
title: Runtime Assets
nav_order: 5
description: Serve the pinned OpenUI JavaScript and CSS bundle with integrity metadata.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to fetch the checksum-locked browser bundle into your Rails app.
* Where to include the runtime stylesheet and Stimulus controllers.
* Which settings are required for externally hosted assets.

## Fetch the self-hosted runtime

Self-hosting is the default. The task vendors the pinned JavaScript, CSS, and license files under `public/openui` and verifies them against the gem's checksums:

```sh
bin/rails openui:runtime:fetch
```

Include the stylesheet in the host layout's `<head>`:

```erb
<%= openui_stylesheet_tag %>
```

For importmap, pin and register both controllers:

```ruby
# config/importmap.rb
pin_all_from OpenUI::Rails::Engine.root.join("app/javascript/openui"), under: "openui"
```

```js
// app/javascript/controllers/index.js
import { application } from "controllers/application"
import OpenUIController from "openui/rails/openui_controller"
import OpenUIEnvelopeController from "openui/rails/openui_envelope_controller"

application.register("openui", OpenUIController)
application.register("openui-envelope", OpenUIEnvelopeController)
```

`openui-envelope` is needed when using the Turbo Streams transport. The runtime URL and integrity metadata are attached to each surface mount.

## External runtime assets

Set `runtime_assets = :external` only when you serve a host-built or externally hosted bundle. Configure `runtime_url`, `runtime_stylesheet_url`, and the corresponding exact integrity hashes. Use exact-version URLs; the gem does not select a floating `latest` release. The external stylesheet URL is required when calling `openui_stylesheet_tag`.

The runtime fetch task requires npm, but disables npm lifecycle scripts and extracts only checksum-verified files. A missing or invalid asset should be fixed by fetching the pinned version or by supplying the complete custom asset configuration.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - complete the Rails view setup.
* [Library and Prompt Contract]({% link _core_features/library-contract.md %}) - check that prompt and runtime describe the same library.
* [Streaming Transports]({% link _advanced/transports.md %}) - connect the browser to a stream source.
