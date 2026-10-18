---
layout: default
title: Stored Messages
nav_order: 6
description: Store an OpenUI response with form context and strip its framing before sending model history.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to frame a response with context for storage.
* How to restore form state and prepare model history.

## Store content and context

Use `Message` when your host stores a response and its form state together:

```ruby
stored = OpenUI::Rails::Message.build(
  content: 'root = TextContent("Ticket received")',
  context: { form: { status: "open" } },
  finished: true
)

parsed = OpenUI::Rails::Message.parse(stored)
parsed.context # => { "form" => { "status" => "open" } }
parsed.finished? # => true
```

This is the upstream message framing format with `]]>openui:` marker lines.
It is not an OpenUI Lang parser. The browser renderer accepts framed content;
your host restores context as `initial_state:` when rendering a surface.
Treat client-supplied form state as untrusted input.

## Prepare model history

Strip framing and context before sending a stored response back to a model:

```ruby
OpenUI::Rails::Message.strip(stored)
# => 'root = TextContent("Ticket received")'
```

Framing does not authorize an action or prove that a user confirmed one.
Keep authorization in the server action path.

## Next Steps

* [Rendering Surfaces]({% link _core_features/surfaces.md %}) - restore a stored response and initial state.
* [Server Actions]({% link _core_features/actions.md %}) - validate and authorize operations.
