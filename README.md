# openui-rails

[![CI](https://github.com/yorzi/openui-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/yorzi/openui-rails/actions/workflows/ci.yml)

Render streaming, interactive OpenUI Lang interfaces inside an existing Rails
application. Use Rails views and Stimulus to mount the official browser runtime;
keep authentication, authorization, and persistence in Rails.

**Unofficial integration:** this project is not affiliated with or maintained by
Thesys. It uses the OpenUI JavaScript runtime and does not implement a Ruby parser
or renderer.

[Documentation](https://openui-rails.wangyaodi.com/) ·
[RubyGems](https://rubygems.org/gems/openui-rails) ·
[Roadmap](ROADMAP.md)

## What you get

- A view helper and Stimulus bridge for rendering server-owned surfaces.
- A shared library fingerprint for the prompt, browser runtime, and stored UI.
- Ordered stream envelopes with gap detection over Turbo Streams or Action Cable.
- One allowlisted action endpoint with authorization, validation, and replay protection.
- An optional RubyLLM streaming adapter.

Your app supplies scoped record lookup, stream subscriptions, snapshot recovery,
and shared idempotency storage when running multiple processes.

## Get started

Requires Ruby 3.2+ and Rails 8.0 or 8.1. On Rails 8.0, use `json < 3`.
The runtime-fetch task also needs npm. RubyLLM is optional.

```ruby
# Gemfile
gem "openui-rails", "~> 0.2.0"
```

```sh
bundle install
bin/rails generate openui:install
bin/rails openui:runtime:fetch
bin/rails openui:library:prepare
bin/rails openui:doctor
```

Follow [Getting Started](https://openui-rails.wangyaodi.com/getting-started/) to
register the Stimulus controllers and include the stylesheet. After setup,
render a surface from an ERB view:

```erb
<%= openui_surface(
  surface: { id: "support-42", response: 'root = TextContent("How can I help?")' },
  label: "Support"
) %>
```

Actions are denied until you configure authorization.

## Documentation and development

The documentation site contains the full guides and API reference:

- [Configuration](https://openui-rails.wangyaodi.com/configuration/)
- [Streaming](https://openui-rails.wangyaodi.com/streaming/) and [server actions](https://openui-rails.wangyaodi.com/actions/)
- [RubyLLM](https://openui-rails.wangyaodi.com/ruby-llm/) and [production setup](https://openui-rails.wangyaodi.com/production/)
- [Upgrading](https://openui-rails.wangyaodi.com/upgrading/) and [API reference](https://openui-rails.wangyaodi.com/api-reference/)

Version `0.2.0` adds default-library preparation and setup diagnostics.
The API may change during `0.x`; see the
[changelog](CHANGELOG.md) and the proposed [path to 1.0](ROADMAP.md).
The site's stable channel follows the latest release; [/next/](https://openui-rails.wangyaodi.com/next/)
follows `main`.

For repository work, use [Contributing](CONTRIBUTING.md),
[Releasing](RELEASING.md), and the dated [0.1.0 audit](AUDIT.md).
Report vulnerabilities through the [security policy](SECURITY.md).

## License

[MIT](LICENSE). See [third-party notices](THIRD_PARTY_NOTICES.md) before
redistributing the OpenUI browser bundle.
