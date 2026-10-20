# Support Desk reference host

This opt-in reference belongs to the host application, outside the engine's
public API. It uses synthetic accounts, recorded generation, the real pinned
OpenUI runtime, SQLite, importmap, and HTTP Turbo Streams. It opts into the
Active Record idempotency store and retains a unique business receipt for closing
a ticket. Shared claims do not replace that database constraint.

The plain HTML fallback provides ticket details, an explicit reload, and a fresh
sign-in. Snapshot recovery is scoped and single-flight. Unknown action outcomes
are never retried automatically. Browser checks cover failure feedback, keyboard
recovery, and Turbo restoration as well as the successful workflow.

From the repository:

```sh
mkdir -p tmp/package
bundle exec gem build openui-rails.gemspec --output tmp/package/openui-rails-0.5.0.gem
bin/check-reference --gem tmp/package/openui-rails-0.5.0.gem --runtime tmp/real-runtime
```

Fetch the runtime first. See the [complete guide](https://openui-rails.wangyaodi.com/reference-workflow/)
for setup, retained-host review, failure checks, and evidence limits. The
reference is not enabled by requiring the gem. Keep the demo loopback-only;
replace its synthetic login before adapting it to a real application.
