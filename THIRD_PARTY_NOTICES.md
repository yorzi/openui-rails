# Third-party notices

`openui-rails` is an **unofficial** integration. It is not affiliated with,
endorsed by, or maintained by Thesys. It does not redistribute the OpenUI
parser or renderer; it references the official, version-pinned JavaScript
runtime, which the host application self-hosts (or fetches from an
exact-version URL it configures).

The Gem itself is licensed under the MIT License (see `LICENSE`).

## Referenced upstream packages

The following `@openuidev/*` packages are published by Thesys under the MIT
License and are loaded by the browser at runtime (self-hosted by the host app,
or referenced at an exact pinned version):

| Package | Pinned version | License |
| --- | --- | --- |
| `@openuidev/browser-bundle` | 0.2.1 | MIT |
| `@openuidev/react-lang` | 1.0.1 | MIT |
| `@openuidev/lang-core` | 1.0.1 | MIT |
| `@openuidev/react-ui` | 0.18.1 | MIT |
| `@openuidev/cli` | 0.6.0 | MIT |

The OpenUI repository is licensed MIT: "Copyright (c) 2011-2024 Thesys Inc."

## Transitive browser dependencies

The official browser bundle inlines dependencies, including React 19. Those
projects are MIT-licensed and their notices must ship with any redistributed
build of the bundle. When you self-host the bundle you are responsible for
including the complete third-party notices of the exact bundle revision you
vendored.

## Naming

"OpenUI" is also the name of an unrelated W3C Community Group. `openui-rails`
is not connected to that group either. No trademark or official-affiliation
permission is claimed or implied.
