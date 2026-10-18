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

## Use the default chat library

The default browser bundle contains `openuiChatLibrary` only. Save its prompt and spec before asking a model to generate UI. Fetch and register the runtime using [Runtime Assets]({% link _core_features/runtime-assets.md %}), then render a local surface with both library paths temporarily set to `nil`. This bootstrap page cannot verify library identity and should only be used locally.

After the runtime loads, run each expression separately in that page's browser console:

```js
const library = window.__OpenUI.openuiChatLibrary
library.prompt()
JSON.stringify(library.toSpec(), null, 2)
```

Save the returned prompt string as `config/openui/library.prompt.txt` and the JSON as `config/openui/library.spec.json`. Save the string value, without console quotes or escape sequences. Restore both paths in the initializer and restart the app. Commit both files and run the validation below. The real-runtime compatibility probe uses `toSpec()` from the pinned bundle to check library identity; it does not qualify arbitrary custom libraries.

## Generate a custom library

A custom prompt does not add components to the default runtime. Build a matching runtime that exposes the same `window.__OpenUI` contract, including its library in the `openuiChatLibrary` slot used by the bridge. Use the pinned CLI to generate the prompt and spec from that library's source:

```sh
npx --yes @openuidev/cli@{{ site.compatibility.cli }} generate ./src/library.ts --out config/openui/library.prompt.txt --no-telemetry
```

The CLI writes a spec file next to the prompt, commonly named `library.prompt.txt.spec.json`. Rename it to `config/openui/library.spec.json`, or set `library_spec_path` to the generated filename. Commit both files. Set `DO_NOT_TRACK=1` in CI in addition to the CLI flag.

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
