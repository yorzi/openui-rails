# Contributing to openui-rails

Thanks for helping. This is an unofficial Rails integration for Thesys OpenUI
Lang; it does not reimplement the OpenUI parser or renderer.

## Getting set up

```bash
git clone https://github.com/yorzi/openui-rails
cd openui-rails
bundle install
bundle exec bin/rails db:test:prepare
```

## Before you open a pull request

```bash
bundle exec bin/rails test        # unit + integration tests
bundle exec bin/rails test:system # browser (system) tests, needs Chrome
bundle exec rubocop               # style (rubocop-rails-omakase)
bundle exec gem build openui-rails.gemspec
bundle exec ruby bin/smoke-package openui-rails-0.1.0.gem
bundle exec bundler-audit check --update
bundle exec ruby -Itest test/compatibility/ruby_llm_smoke.rb
```

The browser tests run against `test/dummy` with headless Chrome and a
deterministic stub of the OpenUI runtime
(`test/dummy/public/openui/openui-browser-bundle-0.2.1.js`), so they need no
network or real bundle.

CI also runs the real checksum-locked browser bundle. To run that probe locally:

```bash
bundle exec rake "app:openui:runtime:fetch[$PWD/tmp/real-runtime]"
OPENUI_REAL_RUNTIME_DIR="$PWD/tmp/real-runtime" \
  bundle exec ruby -Itest test/compatibility/runtime_smoke.rb
```

The first command needs npm and network access. The browser probe uses local
assets afterward. The RubyLLM probe uses the real 2.1.1 client and SSE parser,
with WebMock and a dummy API key. It never calls a paid provider.

Keep the test suite green and add negative/security tests alongside any new
behavior. Changes to the action path or the stream protocol are expected to
include unauthorized, wrong-tenant, replay, stale-version and malformed-payload
cases.

## Guidelines

- Prefer the official OpenUI runtime over any hand-rolled parser. Model output
  is untrusted UI DSL, never executable code.
- Keep `ruby_llm` optional and isolated under `OpenUI::Rails::Adapters`; do not
  reference a `RubyLLM` constant outside a guarded adapter.
- Inside `module OpenUI`, write `::Rails` for the framework.
- Do not introduce floating dependency ranges for the OpenUI JS runtime or the
  prompt CLI; pin exact versions.
- Write commit messages that explain the *why*.

## Reporting security issues

Please do not open a public issue for a security problem. See `SECURITY.md`.

## Code of Conduct

By participating you agree to `CODE_OF_CONDUCT.md`.
