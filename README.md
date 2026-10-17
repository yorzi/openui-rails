# openui-rails

[![CI](https://github.com/yorzi/openui-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/yorzi/openui-rails/actions/workflows/ci.yml)

Render model-generated, streaming, interactive **OpenUI Lang** UI inside an
existing Rails application — without migrating the whole frontend to a
React/Next.js SPA and without hand-writing the stream, state and action glue
for every screen.

> **Unofficial integration.** `openui-rails` is not affiliated with, endorsed
> by, or maintained by Thesys. It reuses the official, version-pinned OpenUI
> JavaScript runtime and keeps Rails authoritative for authentication,
> authorization and persistence. It is not a Ruby reimplementation of OpenUI
> Lang.

## What it does

- **Rails view helper + Stimulus bridge** that mounts the official OpenUI
  renderer against a server-owned surface record.
- **Versioned library/prompt contract** so the model prompt and the browser
  component library are generated from the *same* library revision, with a
  fingerprint persisted alongside the response.
- **Ordered streaming** envelope over Turbo Streams or Action Cable, with
  snapshot recovery when chunks arrive out of order or a client reconnects.
- **A single, authorized action loop**: component `onAction` and browser
  `toolProvider` `Query()` / `Mutation()` calls both route through one
  allowlisted Rails endpoint with CSRF, tenancy and idempotency controls.
- **Optional RubyLLM adapter** that owns RubyLLM-specific event normalization.

RubyLLM is an optional integration, never a core dependency. Rails remains the
source of truth for users, tenants and business objects.

## Status

Early development. The public API is not frozen and may change between `0.x`
releases. See [`CHANGELOG.md`](CHANGELOG.md).

## Installation

```ruby
# Gemfile
gem "openui-rails"
```

```bash
bundle install
bin/rails generate openui:install
```

## Usage (sketch)

```ruby
# config/initializers/openui.rb
OpenUI::Rails.configure do |config|
  config.transport = :turbo
  config.library_spec_path = Rails.root.join("config/openui/library.spec.json")
  config.runtime_assets = :self_hosted
end
```

```erb
<%= openui_surface(surface: @surface, stream: true) %>
```

```ruby
# Optional RubyLLM adapter (not a hard dependency)
OpenUI::Rails::Adapters::RubyLLM.stream(chat: chat, question: question, surface_id: surface.id)
```

## Compatibility

| Component | Supported |
| --- | --- |
| Ruby | `>= 3.2` |
| Rails | `>= 8.0` (< 9.0) |
| OpenUI | pinned JS runtime (see `THIRD_PARTY_NOTICES.md`) |

The support matrix is verified by CI and refined as real matrix runs are
recorded. Unknown provider/version combinations are *unsupported*, not
implicitly compatible.

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md)
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`SECURITY.md`](SECURITY.md)

## License

Released under the [MIT License](LICENSE). OpenUI and the `@openuidev/*`
packages are MIT-licensed by Thesys; their notices ship in
[`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
