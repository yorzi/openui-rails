---
layout: default
title: Supported API
nav_order: 2
description: The Ruby methods, settings, browser events, wire contracts, and runtime pins that the 1.0 compatibility commitment covers.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* Which Ruby classes, settings, tasks, and events you can depend on.
* Which wire formats the browser and server share.
* How the pinned runtime and default library change between releases.

## What the commitment covers

Version 0.9 freezes the candidate API for 1.0. From 1.0, everything on this
page keeps working through every 1.x release. A change that would break it is
deprecated first and removed only in a later major version. Before 1.0, 0.9.x
releases fix defects and do not add features. A defect fix that must change a
contract here is recorded in [Upgrading]({% link _reference/upgrading.md %}).

Anything not listed is internal, even when Ruby lets you call it. Internal
code is marked `:nodoc:` and is absent from the
[generated API reference]({{ '/api/' | relative_url }}). That includes
`RuntimeAsset`, `RuntimePackage`, `DefaultLibrary`, `Doctor`, `Instrumentation`,
`JsonValue`, the Active Record store's model class, and the `data-openui-*`
attribute names that `openui_surface` renders for the Stimulus controller.

## Ruby API

| Area | Supported entry points |
| --- | --- |
| Configuration | `OpenUI::Rails.configure`, `.configuration`, `.actions`, `.deprecator`, `Configuration#validate!`, `#library_fingerprint`, `#library_manifest`, `#reset!` |
| Views | `openui_surface`, `openui_stylesheet_tag`, `Surface.new`, `Surface.coerce`, `Surface#to_h` |
| Library | `LibraryManifest.load`, `.parse`, `.build`, its readers and `#matches?`; `PromptBuilder.load`, `#system_instruction`, `#fingerprint`, `#matches?`, `#to_h` |
| Messages | `Message.build`, `Message.parse`, `Message.strip` |
| Streaming | `Stream::Envelope` and its four constructors, `Stream::Bridge#envelopes`, `#each_envelope`, `#writer`, `Bridge::Writer#push`, `#finish`, `#error_for`, `#sequence`, `#terminated?`, `Stream::Broadcaster`, `Stream::Accumulator`, `Stream::Transports.build` and its three transports |
| Actions | `Actions::Registry#register`, `#fetch`, `#registered?`, `#names`, `#clear!`; `Actions::Schema.define`, `.any`, `.from`; `Actions::Dispatcher.from_configuration`, `.new`, `#call`; `Actions::Invocation`; `Actions::Submission` |
| Idempotency | `Actions::Idempotency::MemoryStore`, `ActiveRecordStore#claim`, `#record`, `#delete_expired`, `Testing::IdempotencyStoreContract` |
| Adapters | `Adapters::RubyLLM.stream` |
| Errors | `OpenUI::Rails::Error` and its ten subclasses |

The [Configuration]({% link _getting_started/configuration.md %}) settings table
is part of this contract. `library_name` and `surface_id_param` are deprecated
and are removed in 1.0.

## Tasks, generators, and notifications

The supported commands are `openui:install` and `openui:idempotency` generators,
plus the `openui:doctor`, `openui:library:prepare[force]`, and
`openui:runtime:fetch[destination]` tasks. Doctor check names and messages can
change; depend on its exit status.

The `action.openui_rails` and `stream.openui_rails` notification names, payload
keys, outcomes, and codes are documented in
[Diagnostics and Recovery]({% link _advanced/diagnostics-and-recovery.md %}).
New keys can be added in a minor release. Existing keys keep their meaning.

## Wire contracts

These formats cross the network or persistence boundary, so a host can rely on
them from its own JavaScript, jobs, and stored records:

| Contract | Defined in |
| --- | --- |
| Action request body, result shape, error codes, and HTTP statuses | [Server Actions]({% link _core_features/actions.md %}) |
| Stream envelope types, fields, sequence rules, and error codes | [Streaming Responses]({% link _core_features/streaming.md %}) |
| Browser events and their `detail` fields | [Diagnostics and Recovery]({% link _advanced/diagnostics-and-recovery.md %}) |
| Idempotency store `claim` and `record` | [Configuration]({% link _getting_started/configuration.md %}#shared-idempotency-store-contract) |
| Stored message markers | [Stored Messages]({% link _core_features/messages.md %}) |
| `openui_action_claims` table | [Shared Idempotency Storage]({% link _advanced/shared-idempotency.md %}) |

A minor release can add an envelope type, an error code, or an event field.
Ignore values you do not recognize, and fall back to generic recovery for an
unknown error code.

## Runtime and library pins

The gem pins `@openuidev/browser-bundle` `{{ site.compatibility.browser_runtime }}`
by exact version and checksum, and ships default library exports generated from
that bundle. The custom-library guide pins `@openuidev/cli`
`{{ site.compatibility.cli }}`.

A pin changes only in a release whose changelog and upgrading guide name the
new version. That release regenerates the default library exports, updates the
checksums, and passes the real-runtime suite. It preserves the contracts on this
page or documents an explicit migration. The gem never accepts a floating
runtime version.

A new default library has a new fingerprint. Surfaces stored with the old
`library_version` then raise `OpenUI::Rails::LibraryVersionError` in
`openui_surface`, and the browser rejects frames for the old library. Plan to
regenerate those responses or render ordinary HTML fallback, as described in
[Rendering Surfaces]({% link _core_features/surfaces.md %}).

## Next Steps

* [Upgrading]({% link _reference/upgrading.md %}) - review changes before updating.
* [API Reference]({% link _reference/api-reference.md %}) - read method-level documentation.
