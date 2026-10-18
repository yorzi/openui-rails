---
layout: default
title: What's New in 0.2
nav_order: 5
description: Prepare the default chat library and inspect local setup before rendering OpenUI in Rails.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to initialize the default library without browser-console copying.
* How to find missing local setup steps without running actions.

Version `{{ site.version }}` is a local development candidate and is not
published. See [Release History]({% link _reference/release-history.md %}) for
published versions.

## Prepare the default library

After installing the engine, copy the exact pinned chat-library exports:

```sh
bin/rails openui:library:prepare
```

The task writes the configured prompt/spec files and their upstream license.
It requires no browser, Node, network, or provider. Repeated runs keep identical
files unchanged; different existing files require explicit overwrite. Read
[Library and Prompt Contract]({% link _core_features/library-contract.md %})
before replacing custom files.

## Inspect local setup

Check library identity, asset checksums, and the engine's action route:

```sh
bin/rails openui:doctor
```

Required failures produce a nonzero exit status. Browser registration,
authorization policy, external assets, shared replay storage, and snapshot
recovery still need application verification. The task prints those limits
without invoking your callbacks or exposing file contents. See
[Setup Diagnostics]({% link _getting_started/setup-diagnostics.md %}).

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - follow the default setup path.
* [Upgrading]({% link _reference/upgrading.md %}) - keep existing custom libraries intact.
