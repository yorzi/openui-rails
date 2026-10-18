---
layout: default
title: Library and Prompt Contract
nav_order: 4
description: Keep the model prompt, browser library, and stored surface aligned to one manifest fingerprint.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to generate the prompt and manifest from one component library.
* Which fingerprint to store on a rendered surface.
* How to validate the configured files before serving traffic.

## Generate a matching prompt and manifest

OpenUI Rails uses the component-library prompt and spec together. The pinned OpenUI CLI writes both outputs from the same source revision:

```sh
npx --yes @openuidev/cli@0.6.0 generate ./src/library.ts --out config/openui/library.prompt.txt --no-telemetry
```

The CLI writes a spec file next to the prompt, commonly named `library.prompt.txt.spec.json`. Rename it to `config/openui/library.spec.json`, or set `library_spec_path` to the generated filename. Commit both files. Set `DO_NOT_TRACK=1` in CI in addition to the CLI flag.

The default browser bundle contains `openuiChatLibrary` only. A custom prompt does not add components to that runtime. A custom library needs a host-built runtime that exposes the same `window.__OpenUI` contract as the bundle.

## Validate and persist the right fingerprint

Configure both files, then run:

```ruby
OpenUI::Rails.configuration.validate!
builder = OpenUI::Rails::PromptBuilder.load
builder.to_h
```

`builder.to_h` reports the library fingerprint and a prompt fingerprint. The prompt fingerprint includes the generated system instruction and the library manifest. Persist that prompt fingerprint with the model response for provenance. Set the surface's `library_version` to `OpenUI::Rails.configuration.library_fingerprint`; the view helper and browser use this manifest fingerprint to reject a runtime mismatch.

If you change the component library, regenerate both files and ensure new responses carry the new fingerprint. Do not relabel old responses as if they were generated from the new prompt.

## Next Steps

* [Runtime Assets]({% link _core_features/runtime-assets.md %}) - install the matching browser runtime.
* [Rendering Surfaces]({% link _core_features/surfaces.md %}) - render the response and its library fingerprint.
* [Configuration]({% link _getting_started/configuration.md %}) - configure manifest and prompt paths.
