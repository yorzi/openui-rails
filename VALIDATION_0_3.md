# 0.3.0 local candidate validation

Date: 2026-10-19. Version 0.3.0 is an unpublished development candidate.
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
| RubyLLM 2.1.1 real SSE parser, mocked HTTP | 1 test, 7 assertions, passed. |
| Reference transactions and HTTP boundaries | 9 tests, 42 assertions, passed. |
| Browser bridge with fixture runtime | 33 tests, 109 assertions, passed. |
| Real pinned browser runtime 0.2.1 | 6 tests, 34 assertions, passed. |
| Existing built-gem setup smoke | Fresh host, installer, library preparation, doctor, real rendering, CSRF action, and mobile layout passed. |
| Built-gem reference workflow | 8 browser tests, 78 assertions, passed, using only the extracted artifact's application code and library files. |
| Style | 135 Ruby files, no offenses. |
| Documentation | Stable 0.2 and next 0.3 built; 20 guides have no lint errors; 1,487 internal guide links and anchors passed. |
| Advisory database | Refreshed at `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485`; no known vulnerabilities found in this bundle. |
| Candidate gate | `ruby bin/check-release --candidate` passed; normal publication checks still require dated notes and `released: true`. |

Regression checks first reproduced missing conversation metadata and absent
surface watermark support. The reference flow additionally exposed premature
saved-state feedback and Rails JSON wrapping in a fresh host. The final checks
cover the repaired behavior, including invalid state types and stale revisions.

The real-browser workflow covers saved draft/reload, conversation continuation,
keyboard mutation, dropped Turbo-envelope recovery, late-frame fencing, expired
identity, wrong-tenant requests, reader authorization, duplicate/stale actions,
CSRF, and 390px layout. Desktop and mobile screenshots were visually inspected.
Browser emulation does not establish physical-device compatibility.

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

- Finish the local Rails 8.0 qualification and retained-host review.
- After an authorized push, require full GitHub CI for the exact candidate,
  including Ruby 3.2/3.3/3.4 with Rails 8.0/8.1 and the packaged real-browser flow.
  Workflow syntax and local checks do not establish a remote CI result.
- With publication authorization, date the 0.3.0 changelog, set `released: true`,
  update the README installation version and release history, then run the strict
  `RELEASE_TAG=v0.3.0 ruby bin/check-release` gate.
- Tag and publish through [RELEASING.md](RELEASING.md). Verify the actual public
  artifact checksum and hosted stable/next pages after deployment.
