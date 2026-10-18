## What and why

Describe the change and the reasoning behind it.

## Checklist

- [ ] `bundle exec bin/rails test` is green.
- [ ] `bundle exec bin/rails test:system` is green (or explain why it is not
      applicable).
- [ ] `bundle exec rubocop` is clean.
- [ ] `bundle exec gem build openui-rails.gemspec` succeeds.
- [ ] New behavior has tests, including negative/security cases where relevant
      (unauthorized, wrong-tenant, replay, stale-version, malformed payload).
- [ ] No new floating dependency range was introduced (OpenUI JS runtime and the
      prompt CLI stay pinned to exact versions).
- [ ] `ruby_llm` remains optional; no `RubyLLM` constant is referenced outside a
      guarded adapter.
- [ ] Docs/CHANGELOG updated if the public API or behavior changed.

## Related issues

Closes #
