---
layout: home
title: "OpenUI Rails"
description: "Render model-generated OpenUI Lang interfaces in Rails while keeping actions, authorization, and persistence on the server."
permalink: /
hero:
  name: "OpenUI Rails"
  text: "OpenUI Lang in Rails, with server-owned actions."
  tagline: "Render model-generated OpenUI Lang interfaces in Rails while keeping actions, authorization, and persistence on the server."
  actions:
    - theme: brand
      text: Get started
      link: /getting-started/
    - theme: alt
      text: View on GitHub
      link: https://github.com/yorzi/openui-rails
features:
  - title: "Rails-owned actions"
    details: "Expose an explicit action allowlist and run host authorization before a handler can cause side effects."
    link: /actions/
    link_text: Server actions
  - title: "Versioned library contract"
    details: "Tie the generated prompt, browser library manifest, and rendered surface to a stable fingerprint."
    link: /library-contract/
    link_text: Library contract
  - title: "Recoverable streams"
    details: "Sequence response events and let the host restore an authoritative snapshot after a delivery gap."
    link: /streaming/
    link_text: Streaming
---

## Install

```sh
{% if site.docs_unreleased %}bundle add openui-rails --git https://github.com/yorzi/openui-rails --branch main{% else %}bundle add openui-rails --version {{ site.version }}{% endif %}
```

## A First Look

The helper emits a mount element. The browser runtime renders the OpenUI Lang response.

```erb
<%= openui_surface(
  surface: {
    id: "support-42",
    response: 'root = TextContent("How can I help?")'
  }
) %>
```

Rails owns the record, runtime assets, actions, and authorization. The gem does not parse or render OpenUI Lang in Ruby.

[Get started]({% link _getting_started/getting-started.md %}) or read [how OpenUI Rails works]({% link _getting_started/overview.md %}).
