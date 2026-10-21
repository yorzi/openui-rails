# 0.9.0 local candidate validation

Date: 2026-10-21. Candidate commit: `49d5303`. Version 0.9.0 is an unpublished
stabilization candidate. This record covers a source audit, the defects it
found, and local verification. It does not establish remote CI, RubyGems
publication, hosted documentation, external adoption, or live-provider success.

## Audit scope

The audit read every Ruby file under `app/`, `config/`, and `lib/`, both
Stimulus controllers, the reference host's JavaScript, and the contract guides.
It compared action, stream, and recovery behavior with the documented contracts
and the pinned 0.2.1 bundle. Each defect below was reproduced first. Its
regression test fails without the fix and passes with it.

## Defects corrected

| Commit | Defect | Evidence |
| --- | --- | --- |
| `d69f24a` | After a `stream_too_large` frame, `Bridge#envelopes`, `Broadcaster.broadcast`, and the RubyLLM adapter kept reading every provider chunk. | A 100-chunk source was fully drained; it now stops after 3. Real RubyLLM 2.1.1 SSE parsing adds no assistant message after the halt. |
| `2c15fc1` | A surface restored from the Turbo cache while paused for a snapshot never emitted `openui:snapshot-required` again, so every later delta was dropped. | Browser test: cache, restore, receive one new request at sequence 1, apply the snapshot. |
| `5d1c79c` | Server-side gem errors reached the browser as HTTP 422 with internal messages, including errors raised after the handler ran. | Endpoint test: an actor without a stable id returns 500, code `error`, message `action failed`; details are logged. |
| `82ed1b9` | An exception from the `on_error` hook replaced the provider error and suppressed the terminal frame, leaving the surface busy. | Bridge test: a failing hook still yields `stream_failed`. |
| `73bcb8d` | A surface without a stored `library_version` accepted frames for any library, although its runtime was verified against the configured fingerprint. | Browser test: a foreign frame reports `library_version_mismatch`; a matching frame applies. |

The audit also documented the default library's `@OpenUrl` step, which reaches
the server as an unregistered `open_url` action (`512728b`). The guide's
allowlist example was executed: one approved HTTPS URL passed, and a foreign
host, a `javascript:` URL, a number, and plain HTTP were rejected before any
idempotency claim.

## Stabilization scope

- `config.library_name` and `config.surface_id_param` report deprecations through
  `OpenUI::Rails.deprecator`, registered in `Rails.application.deprecators`, and
  are removed in 1.0 (`e02995c`).
- The Supported API page names the covered Ruby API, settings, tasks,
  notifications, wire contracts, and runtime pin policy. `RuntimeAsset` is marked
  internal (`496bbd0`).
- Candidate metadata, What's New in 0.9, the 0.5 to 0.9 upgrading guide, and
  release history are prepared. README installation stays on published 0.5.0.

Considered and left unchanged: a stale action returns `stale_surface` before a
replay lookup. The shared-idempotency guide already documents this ordering.

## Verified locally

Ruby is 3.3.5. Database suites ran sequentially. Both Rails lines used SQLite and
the real checksum-locked browser runtime 0.2.1.

| Check | Rails 8.1.4 / JSON 3.1.0 | Rails 8.0.5.1 / JSON 2.21.2 |
| --- | --- | --- |
| Core suite | 264 tests, 793 assertions, passed | 264 tests, 793 assertions, passed |
| RubyLLM 2.1.1 SSE with mocked HTTP | 2 tests, 11 assertions, passed | 2 tests, 11 assertions, passed |
| Reference transactions | 9 tests, 52 assertions, passed | 9 tests, 52 assertions, passed |
| Fixture-runtime browser bridge | 39 tests, 142 assertions, passed | 39 tests, 142 assertions, passed |
| Pinned real-runtime compatibility | 6 tests, 34 assertions, passed | 6 tests, 34 assertions, passed |
| Built-gem setup, doctor, rendering, CSRF action, mobile layout | Passed | Passed |
| Built-gem reference browser workflow | 14 tests, 144 assertions, passed | 14 tests, 144 assertions, passed |
| Style | 144 files, no offenses | 144 files, no offenses |
| Candidate gate | `bin/check-release --candidate` passed | Passed |

The documentation built stable 0.5.0 at `/` and the 0.9.0 working tree at
`/next/`, with the API reference. New anchors resolve, the internal
`RuntimeAsset` page is absent, and new front matter avoids `&`, `<`, and `>`.
`bundler-audit check` against the advisory database updated on 2026-10-21
(1,266 advisories) found no known vulnerabilities. Screenshots for the two new
browser tests were inspected and match their assertions.

## Local artifacts

Each Rails line built its own archive from `49d5303`: 93,696 bytes and 80 files
on Rails 8.1, SHA-256
`3ef46e715fb72c72910c3c0c64393334e7fe862b74e26c6df734520f04522eda`; the Rails 8.0
build is `0d22bf84e82b1c085c34b32d116c75c72d9da38fdd88aedd4f1aad1a465d352c`.
Archive timestamps differ, so these are local identifiers, not a release
checksum. Publish only the artifact the tagged CI run builds.

## Open 1.0 qualification gates

- Ruby 3.2 and 3.4 and the remote CI matrix for the pushed candidate commit.
  Only Ruby 3.3 was available locally.
- A maintainer integration in a real Rails host outside `test/dummy`, using only
  public APIs, with setup friction recorded.
- One explicitly authorized, budget-bounded live-provider flow from prompt
  through rendering and an authorized action.
- The upgrade rehearsal from 0.1.0, including persisted UI and library
  mismatches, plus a verified rollback path.
- A fresh review of bundled-runtime notices, CSP requirements, and remaining
  accessibility limits. The runtime pin is unchanged since 0.5.0.

Publication still requires owner approval under [RELEASING.md](RELEASING.md).
Use 0.9.x patches for defects found while closing these gates.
