# Third-party notices

`openui-rails` is an **unofficial** integration. It is not affiliated with,
endorsed by, or maintained by Thesys. It does not redistribute the OpenUI
parser or renderer; it references the official, version-pinned JavaScript
runtime, which the host application self-hosts (or fetches from an
exact-version URL it configures).

The Gem itself is licensed under the MIT License (see `LICENSE`).

## Referenced upstream packages

The integration references these official MIT-licensed packages. The browser
bundle and the maintainer CLI have exact pins. The other rows describe the
browser bundle's declared dependency ranges, not proven compiled versions.
The CLI is a development tool and is not loaded in the browser.

| Package | Version reference | License |
| --- | --- | --- |
| `@openuidev/browser-bundle` | 0.2.1 exact runtime pin | MIT |
| `@openuidev/react-lang` | ^1.0.1 declared range | MIT |
| `@openuidev/react-ui` | ^0.18.1 declared range | MIT |
| `@openuidev/cli` | 0.6.0 exact guide pin | MIT |

The OpenUI repository is licensed MIT: "Copyright (c) 2011-2024 Thesys Inc."

## Default-library exports

The gem includes the `openuiChatLibrary.prompt()` and `toSpec()` exports from
the exact pinned browser bundle under `lib/openui/rails/default_library/`.
`provenance.json` records the runtime integrity pin and export checksums. The
upstream MIT license accompanies them as `openui.LICENSE.txt` and is copied
alongside application artifacts by `openui:library:prepare`. Preserve it when
redistributing these exports. The exports contain library definitions and
prompt instructions, not the browser renderer implementation.

## Transitive browser dependencies

The 2026-10-28 review checks the exact checksum-locked 0.2.1 JavaScript, CSS,
and upstream license used by the demo. Its JavaScript's final bundled-notices
block names these package groups:

| Embedded package group | Notice |
| --- | --- |
| `react`, `react-dom`, `scheduler`, `use-sync-external-store` | Meta copyright and MIT references. |
| `lucide-react` | Version 0.562.0 and ISC references across its bundled icon modules. |
| `@tanstack/table-core`, `@tanstack/react-table` | TanStack copyright and MIT references. |

These are the groups named by the embedded notices, not a reconstructed lockfile
or complete dependency inventory. The npm browser-bundle manifest declares
ranges for React, React DOM, react-ui, and react-lang. Those ranges do not
identify every resolved transitive version. Preserve the fetched files intact;
do not strip their legal comments. A host that redistributes the bundle must
still establish its complete dependency and license inventory.

The reviewed manifest is the [immutable npm version record](https://registry.npmjs.org/@openuidev/browser-bundle/0.2.1).

The official browser bundle inlines dependencies, including React 19. They do
not all share one license. The pinned bundle's embedded notices identify
`lucide-react` 0.562.0 as ISC-licensed. React and TanStack identify MIT licenses.
Their notices must accompany any redistributed bundle.

The fetch task preserves the upstream license and the bundle's embedded legal
comments. These do not establish that all transitive notice obligations have
been satisfied. The gem package does not include that browser bundle. Before
redistributing the fetched bundle, the host application's owner must review
the complete dependency/license inventory for that exact bundle. This document
does not claim legal clearance.

## Naming

"OpenUI" is also the name of an unrelated W3C Community Group. `openui-rails`
is not connected to that group either. No trademark or official-affiliation
permission is claimed or implied.
