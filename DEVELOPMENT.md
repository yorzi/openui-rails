# Development and verification

Use `test/dummy` as the maintained local host. Temporary generated hosts verify
the built gem. Keep examples synthetic and provider-free unless a task explicitly
authorizes a live call. Follow this loop for each feature:

1. Reproduce the behavior with a focused test through its public entry point.
2. Implement the change and update its guide in the same commit.
3. Run the focused checks, then `bin/check`. Run database suites sequentially.
4. For browser behavior, run the relevant suite, inspect its screenshots, and
   use browser tools for keyboard, layout, or mobile questions left unresolved.
5. Commit a completed unit with its actual verification results. Stop any
   task-owned service before finishing.

## Checks

```sh
bin/check
bin/check --browser --docs
# Requires npm and network only for this explicit fetch:
bundle exec rake "app:openui:runtime:fetch[$PWD/tmp/real-runtime]"
bin/check-browser --runtime tmp/real-runtime
# Run all local checks including both browser layers:
bin/check --runtime tmp/real-runtime --docs
# Focus on one browser test file:
bin/check-browser test/system/openui_confirmation_system_test.rb
```

Chrome is required. Set `CHROME_BIN` for a nonstandard executable. Selenium
manages the driver; its first run may need a download. Each browser run uses a
temporary SQLite database and stores passed and failed fixture screenshots in
the printed `tmp/browser/` directory. Screenshots are evidence for visual
review, not a substitute for assertions. Logs, databases, and screenshots stay
in ignored directories. Do not put production data in them.

The Capybara server and driver port probe bind loopback. Test processes close
their browser sessions and remove the temporary database on exit. This is not
a browser network sandbox. The stub suite exercises bridge failure cases; the
real-runtime suite verifies the pinned renderer, library identity, actions,
tools, and keyboard behavior. Neither proves live-provider compatibility.

## Refresh the default library exports

When changing the pinned runtime, regenerate from its checksum-verified bundle:

```sh
bin/export-default-library tmp/real-runtime
bin/export-default-library tmp/real-runtime --check
```

This maintainer command uses the existing Selenium/Chrome development tools,
closes the browser afterward, and preserves the upstream license and provenance.
Review the generated files and run the real-runtime tests. Applications use the
exported files inside the gem and need none of these browser tools for preparation.

## Installed artifact and release checks

`bin/check` builds into `tmp/package/` and tests a new Rails host using that
artifact. It verifies default library preparation, repeat runs, overwrite
rejection, missing-setup doctor exits, eager load, and HTTP mount rendering.
With `--runtime`, it also verifies a successful doctor report, actual rendering,
an explicitly authorized CSRF-protected action, and a 390px mobile page in a
fresh host. The host reads its prompt/spec from the gem, never test fixtures.
Fixture screenshots use the same `tmp/browser/` tree. CI runs this path too.
This does not establish external adoption or remote CI success.
Dependency-advisory refreshes remain explicit network operations; run
`bundle exec bundler-audit check --update` before a release. Follow
[Releasing](RELEASING.md) for the remaining publication checks.
