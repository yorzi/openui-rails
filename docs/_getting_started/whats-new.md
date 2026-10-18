---
layout: default
title: What's New in 0.1
nav_order: 6
description: Learn what the first OpenUI Rails release provides and which responsibilities stay in your Rails application.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which capabilities are documented on the current default branch.
* Which integration boundaries to review before deploying your application.

## First release

Version `{{ site.version }}` introduces the Rails engine, stream protocol, and action bridge. The initial release is dated 2026-10-18. The Ruby API can change in later `0.x` releases. Read [Upgrading]({% link _reference/upgrading.md %}) before moving from an earlier Git checkout.

The current implementation includes:

* A Rails view helper and Stimulus bridge for mounting the pinned browser renderer.
* A prompt and library-manifest contract with runtime fingerprint checks.
* Ordered stream envelopes with client-side gap detection.
* One allowlisted action endpoint for component actions and browser tool calls.
* An optional RubyLLM adapter for completion streaming.

Read the [release history]({% link _reference/release-history.md %}) for the version status, and check the [GitHub releases](https://github.com/yorzi/openui-rails/releases) for published release notes.

Your application supplies authentication, tenant-scoped surface lookup, authorization, shared idempotency storage, and snapshot recovery. The gem does not provide a persistence layer or a snapshot endpoint. Review [Production]({% link _advanced/production.md %}) before deployment.

## Next Steps

* [Getting Started]({% link _getting_started/getting-started.md %}) - install the engine and render a surface.
* [Changelog on GitHub](https://github.com/yorzi/openui-rails/blob/main/CHANGELOG.md) - review dated changes.
