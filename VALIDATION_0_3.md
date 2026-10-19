# 0.3.0 local candidate validation

Date: 2026-10-19. This record captures the unpublished 0.3.0 development
candidate before release preparation. Its artifact checksum and local-only
evidence remain historical; they do not identify the published artifact.
See [RELEASE_0_3.md](RELEASE_0_3.md) for publication and remote verification.
This work prepares the implementation, local verification, gem package, and
release documentation. It does not establish remote CI, hosted documentation,
RubyGems publication, or live-provider success.

## Delivered scope

- Packaged opt-in `examples/support_desk` reference host, reused by `test/dummy`
  and a freshly generated consumer of the built gem.
- Default library, SQLite, importmap, HTTP Turbo Streams, real Query/Mutation,
  scoped records, persisted drafts and user turns, and canonical snapshots.
- Restored `Surface#next_sequence` and `completed`, with validated mount data.
- Official `@ToAssistant` message/form metadata reaches the host action handler.
  Strict action schemas must allow the metadata they consume.
- `bin/check-reference`, screenshots, negative HTTP/browser checks, CI wiring,
  and candidate metadata validation separated from the publication gate.

## Verified locally

| Check | Result |
| --- | --- |
| Ruby 3.3.5 / Rails 8.1.4 / JSON 3.1.0 | 232 tests, 619 assertions, no failures, errors, or skips. |
| Ruby 3.3.5 / Rails 8.0.5.1 / JSON 2.21.2 | 232 tests, 619 assertions, no failures, errors, or skips. |
| RubyLLM 2.1.1 real SSE parser, mocked HTTP | 1 test, 7 assertions on both Rails lines, passed. |
| Reference transactions and HTTP boundaries | Final CSRF-enabled checks: 9 tests, 52 assertions on both Rails lines, passed. |
| Browser bridge with fixture runtime | 33 tests, 109 assertions on both Rails lines, passed. |
| Real pinned browser runtime 0.2.1 | 6 tests, 34 assertions on both Rails lines, passed. |
| Existing built-gem setup smoke | Fresh host, installer, library preparation, doctor, real rendering, CSRF action, and mobile layout passed. |
| Final built-gem reference workflow | 8 browser tests, 81 assertions on both Rails lines, passed, using only the extracted artifact's application code and library files. |
| Public review command | Generated a retained host, then used the documented loopback server command without test-driver overrides. Real browser sign-in, draft save/reload, conversation continuation, and keyboard close passed. |
| Style | 135 Ruby files, no offenses. |
| Documentation | Stable 0.2 and next 0.3 built; 20 guides have no lint errors; 1,487 internal guide links and anchors passed. |
| Advisory database | Refreshed at `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485`; no known vulnerabilities found in this bundle. |
| Candidate gate | `ruby bin/check-release --candidate` passed; normal publication checks still require dated notes and `released: true`. |

Regression checks first reproduced missing conversation metadata and absent
surface watermark support. The reference flow additionally exposed premature
saved-state feedback, Rails JSON wrapping in a fresh host, and relative
`BUNDLE_GEMFILE` resolution after changing subprocess directories. Manual review
also exposed missing CSRF tags in a test-environment server. The reference now
enables protection itself; its browser driver asserts this instead of setting
it. The final checks cover the repaired behavior, including invalid state types,
missing CSRF tokens on state and action endpoints, and stale revisions.

The real-browser workflow covers saved draft/reload, conversation continuation,
keyboard mutation, dropped Turbo-envelope recovery, late-frame fencing, expired
identity, wrong-tenant requests, reader authorization, duplicate/stale actions,
CSRF, and 390px layout. Desktop and mobile screenshots were visually inspected.
Browser emulation does not establish physical-device compatibility.

## Final artifact

Artifact: `tmp/package/openui-rails-0.3.0.gem`, 86,528 bytes, 75 packaged files.
SHA-256:

```text
81043f5cdaa3fbb652e94a89b790e2def1593ba9347ed70bffc8e70d53910c02
```

Both final built-gem browser runs consumed these exact bytes. The package
contains no fetched browser bundle, database, nested gem, environment file,
or temporary test artifacts. The generated review host remains under ignored
`tmp/support-desk-0.3-final-review`; no service remains running.

## Reproduce

```sh
bin/check --runtime tmp/real-runtime --docs
bin/check-reference --runtime tmp/real-runtime
bin/check-reference --gem tmp/package/openui-rails-0.3.0.gem --runtime tmp/real-runtime
```

Fetch the pinned runtime explicitly first. See [DEVELOPMENT.md](DEVELOPMENT.md)
and the Reference Workflow guide. Raw logs, generated hosts, screenshots, and
synthetic databases stay ignored. Package tests use cached dependencies;
they are not a clean online dependency installation or external adoption test.
The reference uses recorded generation and process-local gem idempotency.
Its database receipt guards one business operation; it is not a shared replay
adapter or an exactly-once guarantee for external side effects.

Two documentation warnings are expected while the candidate remains unpublished:
version 0.3.0 differs from release tag v0.2.0, and `released: false` coexists
with that tag. Keep the stable channel at 0.2.0 until publication.

## Remaining release gates

- After an authorized push, require full GitHub CI for the exact candidate,
  including Ruby 3.2/3.3/3.4 with Rails 8.0/8.1 and the packaged real-browser flow.
  Workflow syntax and local checks do not establish a remote CI result.
- With publication authorization, date the 0.3.0 changelog, set `released: true`,
  update the README installation version and release history, then run the strict
  `RELEASE_TAG=v0.3.0 ruby bin/check-release` gate.
- Tag and publish through [RELEASING.md](RELEASING.md). Verify the actual public
  artifact checksum and hosted stable/next pages after deployment.

All task-owned servers and browser sessions were stopped after verification.
