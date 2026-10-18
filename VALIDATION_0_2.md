# 0.2.0 local validation

Date: 2026-10-18. Status: the planned 0.2 setup features are implemented and
locally validated. Version 0.2.0 is an unpublished candidate. No tag, push,
GitHub deployment, or RubyGems publication is part of this work.

## Delivered scope

- `openui:library:prepare` copies the pinned default prompt, spec, and upstream
  license using Ruby alone. Repeat runs preserve identical files; different
  files require explicit overwrite. Outputs stay within the application root.
- `openui:doctor` checks configuration, static mounts, default library identity,
  local asset checksums, and configured integrity. Dynamic routes, browser
  setup, external assets, host authorization, replay storage, and recovery
  remain explicitly unverified. It does not execute authorization, surface, or
  request-constraint callbacks, print file contents, or fetch assets.
- The install generator leads with the default library. Manifest name queries
  support upstream name-keyed maps without changing fingerprints.
- Agent verification uses a shared check entry point, disposable browser
  databases, loopback services, fixture screenshots, and a built-gem host E2E.

## Results

All counts below exclude the separate intentional failure-artifact probe.

| Check | Result |
| --- | --- |
| Ruby 3.3.5, Rails 8.1.4, JSON 3.1.0 | 227 tests, 600 assertions; no failures, errors, or skips. |
| Ruby 3.3.5, Rails 8.0.5.1, JSON 2.21.2 | 227 tests, 600 assertions; no failures, errors, or skips. |
| RubyLLM 2.1.1 SSE parsing with mocked HTTP | 1 test, 7 assertions on both Rails lines; no failures. |
| Browser bridge suite on Rails 8.1 | 32 tests, 104 assertions; no failures. |
| Real pinned runtime on Rails 8.1 | 6 tests, 33 assertions; exports, rendering, keyboard action, Query, Mutation, and invalid components. |
| Built gem in a new Rails host | Install, doctor failure exits, preparation, repeat runs, overwrite rejection, eager load, and HTTP rendering passed on both Rails lines. |
| Built gem browser E2E on Rails 8.1 | Wrong SRI rejected; successful doctor, real rendering, default-denied action policy, explicit host authorization, CSRF-protected action, and 390px layout passed. |
| Failure screenshots | An intentionally failed browser fixture exited 1 and produced its failed screenshot. |
| RuboCop | 118 files, no offenses. |
| Documentation | Stable 0.1 and next candidate built; 18 guides linted with no errors; 1,208 local guide links and anchors passed. |
| Ruby advisory check | Refreshed database at `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485`; no known vulnerabilities found in the current bundle. |

The docs linter reports two expected warnings: the candidate version differs
from tag v0.1.0, and `released: false` coexists with that release tag. Keep the
candidate unpublished; do not change those values merely to silence warnings.
The modified CI workflow parses as YAML; its GitHub execution remains unverified.

## Reproduce and inspect

```sh
bin/check --runtime tmp/real-runtime --docs
```

Fetch the pinned runtime explicitly first, as described in
[DEVELOPMENT.md](DEVELOPMENT.md). The browser runner prints its screenshot
directory under ignored `tmp/browser/`. Desktop and 390px package screenshots
and the diagnostics guide were visually reviewed. Mobile evidence is browser
emulation, not a physical-device audit.

Validated artifact: `tmp/package/openui-rails-0.2.0.gem`. SHA-256:

```text
a5bc428e933105cdaf7c41e439f9713d5496b18377f2e9741654468cfa4eb667
```

The temporary host uses the developer's cached dependencies and the extracted
built gem. Its prompt/spec come from that gem, not checkout fixtures. This is
not a clean online dependency resolution or external adoption test.

## Remaining release work

Ruby 3.2 and 3.4 were not run locally. After an authorized push, require the
configured GitHub matrix and browser/package jobs to pass for the exact
candidate. Date the changelog, update release status and documentation metadata,
then follow [RELEASING.md](RELEASING.md) for owner-approved publication.
No live provider call was made for 0.2.0. The default memory idempotency store
still has its documented single-process limits.

All task-owned browser sessions, test servers, and the documentation preview
were stopped. Raw run logs, generated hosts, and screenshots are not committed.
