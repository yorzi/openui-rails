---
layout: default
title: Upgrading
nav_order: 2
description: Move an OpenUI Rails application between documented gem releases with the required code and configuration changes.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to prepare an application for 0.3.0.
* How to preserve existing library files and host authorization.

## Upgrade from 0.2.0

{% if site.docs_unreleased %}{% unless site.released %}Version `{{ site.version }}` is an unpublished development candidate. {% endunless %}This channel follows `main`. After the candidate is pushed, test it with a Git dependency:

```ruby
gem "openui-rails", git: "https://github.com/yorzi/openui-rails", branch: "main"
```
{% else %}Set the new version in your application's `Gemfile`:

```ruby
gem "openui-rails", "~> {{ site.version }}"
```
{% endif %}

Run `bundle update openui-rails`. The engine requires no database migration or controller change. The opt-in reference host has its own example application tables. Existing applications do not need to rerun the installer or replace a working library.

## Inspect setup without replacing custom files

```sh
bin/rails openui:doctor
```

Review failures and unverified checks using [Setup Diagnostics]({% link _getting_started/setup-diagnostics.md %}). The task does not certify your host's authorization, browser integration, shared store, or recovery flow.

Use `openui:library:prepare` only when you want the pinned default chat library. It preserves identical files and rejects different existing files before writing. Back up custom prompts, specs, and runtime builds before using the explicit overwrite argument. See [Library and Prompt Contract]({% link _core_features/library-contract.md %}).

For older applications, first read the [0.2.0 migration notes](https://github.com/yorzi/openui-rails/blob/v0.2.0/docs/_reference/upgrading.md).

## Prepare for 0.3.0

On the development branch, `continue_conversation` receives optional `message`,
`form_state`, and `form_name` arguments from the official runtime. Update a
strict action schema to permit the metadata your handler consumes. Treat every
field as untrusted input. Existing `params` and `context` are still forwarded.
Other action types keep their argument shape.

Persisted surfaces can now restore `next_sequence` and `completed` through
`openui_surface`. They default to `0` and `false`, preserving existing mounts.
No engine database migration is required.

## Plan a rollback

Review the target version's upgrade guide and changelog before downgrading the gem. Keep the matching runtime, prompt, and spec together. A library fingerprint mismatch prevents mounting; the host must display a fallback. Do not assume older versions can read every newer snapshot or schema. Restore compatible host data or regenerate affected UI when needed.

## Next Steps

* [What's New]({% link _getting_started/whats-new-in-0-3.md %}) - see the current feature overview.
* [Release History]({% link _reference/release-history.md %}) - check published versions.
