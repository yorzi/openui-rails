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

The default browser bundle contains `openuiChatLibrary` only. After running the install generator, prepare its matching prompt and spec:

```sh
bin/rails openui:library:prepare
```

This task copies the gem's checksum-verified exports of the pinned runtime's `prompt()` and `toSpec()` methods to the configured `prompt_path` and `library_spec_path`. It also copies `openui.LICENSE.txt` beside the prompt. It needs no browser, Node, network, or provider. Commit all three files and preserve the upstream license when redistributing them. Fetch and register the runtime separately using [Runtime Assets]({% link _core_features/runtime-assets.md %}).

Repeated preparation leaves identical files untouched. If any existing output differs, the task stops before writing. Back up custom files before explicitly replacing them:

```sh
bin/rails 'openui:library:prepare[true]'
```

Both configured paths must be regular files within the application root. Paths that resolve outside that root and symlink file targets are rejected, including with overwrite enabled. The task does not change the initializer or authorize actions.

The real-runtime suite compares the shipped exports with the actual browser library. A custom library still requires its own matching runtime and exports.

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

To inspect declared names, use the manifest queries. They accept array
collections and name-keyed maps, including the pinned runtime's spec:

```ruby
manifest = OpenUI::Rails.configuration.library_manifest
manifest.component_names.include?("TextContent") # => true for the default library
```

## Next Steps

* [Runtime Assets]({% link _core_features/runtime-assets.md %}) - install the matching browser runtime.
* [Rendering Surfaces]({% link _core_features/surfaces.md %}) - render the response and its library fingerprint.
* [Configuration]({% link _getting_started/configuration.md %}) - configure manifest and prompt paths.
* [Setup Diagnostics]({% link _getting_started/setup-diagnostics.md %}) - inspect local setup and unresolved host responsibilities.
