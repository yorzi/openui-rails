---
layout: default
title: API Reference
nav_order: 1
guide: false
description: RDoc reference for the public OpenUI Rails classes and methods.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

The [generated API reference]({{ '/api/' | relative_url }}) opens on the `OpenUI` module. It is generated from the source comments.

| If you need to... | Start with |
| --- | --- |
| Configure the engine and integrations | [`OpenUI::Rails::Configuration`]({{ '/api/OpenUI/Rails/Configuration.html' | relative_url }}) |
| Render a mount or model a surface | [`ViewHelper`]({{ '/api/OpenUI/Rails/ViewHelper.html' | relative_url }}), [`Surface`]({{ '/api/OpenUI/Rails/Surface.html' | relative_url }}) |
| Build a prompt and validate its manifest | [`PromptBuilder`]({{ '/api/OpenUI/Rails/PromptBuilder.html' | relative_url }}), [`LibraryManifest`]({{ '/api/OpenUI/Rails/LibraryManifest.html' | relative_url }}) |
| Normalize a stream | [`Stream::Bridge`]({{ '/api/OpenUI/Rails/Stream/Bridge.html' | relative_url }}), [`Stream::Envelope`]({{ '/api/OpenUI/Rails/Stream/Envelope.html' | relative_url }}) |
| Deliver stream frames | [`Stream::Broadcaster`]({{ '/api/OpenUI/Rails/Stream/Broadcaster.html' | relative_url }}), [`Stream::Transports`]({{ '/api/OpenUI/Rails/Stream/Transports.html' | relative_url }}) |
| Register and dispatch actions | [`Actions::Registry`]({{ '/api/OpenUI/Rails/Actions/Registry.html' | relative_url }}), [`Actions::Dispatcher`]({{ '/api/OpenUI/Rails/Actions/Dispatcher.html' | relative_url }}) |
| Coordinate shared action claims | [`Actions::Idempotency::ActiveRecordStore`]({{ '/api/OpenUI/Rails/Actions/Idempotency/ActiveRecordStore.html' | relative_url }}), [storage guide]({% link _advanced/shared-idempotency.md %}) |
| Observe outcomes or recover the browser | [Diagnostics and Recovery]({% link _advanced/diagnostics-and-recovery.md %}) |
| Use the RubyLLM adapter | [`Adapters::RubyLLM`]({{ '/api/OpenUI/Rails/Adapters/RubyLLM.html' | relative_url }}) |

For Markdown, open the [API class index]({{ '/api/index.md' | relative_url }}). Every HTML class page has a matching `.md` page.

Build the reference locally with `docs/bin/build-api.sh tmp/api`.
