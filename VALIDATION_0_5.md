# 0.5.0 local candidate validation

Date: 2026-10-21. Implementation commit: `8e5cd0b`. Version 0.5.0 is an
unpublished development candidate. This record covers local implementation,
packaging, browser checks, and documentation. It does not establish remote CI,
hosted deployment, RubyGems publication, or live-provider reliability.

## Delivered scope

- `action.openui_rails` and `stream.openui_rails` notifications with fixed
  outcomes, error codes, monotonic operation duration, replay status, and stream
  sequence and byte counts. No application content, identities, or exceptions
  are included. Subscriber failures do not change a business outcome.
- Stable browser error codes plus `openui:ready` and `openui:snapshot-applied`.
  Browser events, HTTP codes, timing boundaries, and recovery choices have one
  canonical guide in `docs/_advanced/diagnostics-and-recovery.md`.
- Connection guards for late action responses and retained renderer callbacks,
  including tools, state, and errors. Failed runtime script nodes are removed.
- Plain HTML ticket details outside the renderer, explicit reload and sign-in,
  single-flight authorized snapshot recovery, and keyboard-accessible controls
  in the packaged reference. Unknown mutation outcomes are not retried.
- Snapshot acceptance no longer dismisses authentication or permission feedback.
  Host stream, state-save, and snapshot callbacks discard disconnected results.
- Candidate metadata, What's New, upgrading, API links, and reference guides.
  README installation stays at published 0.4.0; 0.5.0 is explicitly unpublished.

The memory/shared replay contract, business constraints, runtime pin, and gem
dependencies remain unchanged. No scheduler, retry framework, or new adapter is
introduced.

## Verified locally

Ruby is 3.3.5. Database-backed suites ran sequentially. Both Rails lines use
SQLite and the real checksum-locked browser runtime 0.2.1.

| Check | Result |
| --- | --- |
| Rails 8.1.4 / JSON 3.1.0 core suite | 258 tests, 772 assertions, no failures, errors, or skips. |
| Rails 8.0.5.1 / JSON 2.21.2 core suite | 258 tests, 772 assertions, no failures, errors, or skips. |
| RubyLLM 2.1.1 SSE parser with mocked HTTP | 1 test, 7 assertions on each Rails line, passed. |
| Reference transactions and HTTP boundaries | 9 tests, 52 assertions on each Rails line, passed. |
| Fixture-runtime browser bridge | 37 tests, 131 assertions on each Rails line, passed. |
| Pinned real-runtime compatibility | 6 tests, 34 assertions on each Rails line, passed. |
| Built-gem setup | Fresh host, optional migration, process restart replay, library preparation, doctor, real rendering, CSRF action, and mobile layout passed on each Rails line. |
| Built-gem reference browser workflow | 14 tests, 144 assertions on each Rails line, passed using only the extracted application and library files. |
| Style | 144 Ruby files inspected, no offenses. |
| Documentation | Stable 0.4 and next 0.5 built; 24 guides have no lint errors; 1,991 generated guide links and anchors passed. |
| Dependencies | Cached advisory database check found no known vulnerabilities. No network advisory refresh was performed in this development task. |
| Candidate gate | `ruby bin/check-release --candidate` passed. Release metadata remains intentionally incomplete. |

Tests first reproduced absent server notifications, missing runtime/network
codes, an unacknowledged accepted snapshot, and late action success after
reconnect. A retained renderer originally sent two requests and one old state
event through the new connection; the regression now verifies zero requests and
zero state events. A late accepted snapshot originally cleared permission
feedback; the final flow preserves the alert and inert island until a new sign-in.

Notification tests assert exact payload keys, including error paths, and check
that synthetic private markers are absent. Application exceptions remain intact
for the caller without Active Support automatically attaching them to telemetry.
An observer failure cannot replace the handler exception or break completion.

The reference checks runtime blocking using the host's actual runtime URL,
library mismatch, provider error envelopes, an actual byte-limit rejection,
sequence gaps, failed snapshot reads, stale actions, and expired identity.
Snapshot failure waits for an explicit keyboard retry; duplicate gap delivery
does not launch repeated reads. Turbo restoration permits one normal read-only
Query, starts no duplicate stream, and sends one explicit business Mutation.

The mobile fallback test uses Tab to reach Reload conversation and Enter to
activate it. It checks busy state, visible feedback, and horizontal overflow at
390px. Desktop workflow and mobile fallback screenshots were visually inspected.
This is browser emulation, not physical-device or cross-browser qualification.

The docs impact scan's only new unmentioned Ruby name is the internal
`Instrumentation` module, marked `:nodoc:`. Public notification fields and browser
events are documented; generated API pages are not edited by hand.

## Local artifact

Artifact: `tmp/package/openui-rails-0.5.0.gem`, 91,648 bytes, 80 packaged files.
SHA-256:

```text
ca072142c3dc93deb521f5c3ab632d25d095c9fbe208658cdb8def0939e226f6
```

This identifies the final Rails 8.0 local build. Both complete Rails runs tested
built gems from the implementation source; the final archive checksum is not a
claim that the two independently built archives have identical bytes. Inspect
and verify the actual publication artifact again during the release process.
The package excludes downloaded runtime bundles, databases, environment files,
nested gems, and temporary evidence. Consumer checks use cached dependencies,
not a clean online resolver or evidence of external adoption.

## Reproduce

```sh
bin/check --runtime tmp/real-runtime --docs
```

Fetch the pinned runtime explicitly first; see [DEVELOPMENT.md](DEVELOPMENT.md).
For Rails 8.0, use its absolute `BUNDLE_GEMFILE`, `RAILS_VERSION=8.0`,
`RAILS_ENV=test`, and a separate test database. Run suites sequentially.
Raw logs and screenshots remain ignored under `tmp/evidence` and `tmp/browser`.
Two documentation warnings are expected: version 0.5.0 differs from v0.4.0,
and `released: false` coexists with that published tag.

## Boundaries and remaining gates

- Notifications report dispatcher outcomes and writer terminal-frame creation,
  not CSRF or middleware rejection before dispatch, delivery, or an abandoned
  writer. Use payload `duration_ms`, not notification delivery duration.
- Browser event results, state, and messages may contain application data.
  Only the server notification contract is content-free by default. The optional
  `on_error` hook still receives raw exceptions.
- Ready and snapshot-applied events do not guarantee successful React painting.
  Keep fallback available for later renderer errors. Cancelling a fetch cannot
  undo a business effect; retain operation uniqueness and receipts.
- No live provider was called. Provider failures are deterministic frames, while
  RubyLLM parsing is verified with mocked HTTP. Shared-store limits from 0.4 remain.
- After an authorized push, require CI for Ruby 3.2/3.3/3.4 and Rails 8.0/8.1,
  security, style, built-artifact browsers, and documentation. Only Ruby 3.3.5
  was exercised locally.
- Before publication, date the changelog, set released metadata and installation
  versions, pass the strict release gate, and follow [RELEASING.md](RELEASING.md)
  for tags, OIDC, public checksums, installation, and actual hosted content.
  A successful Pages job alone is insufficient.

No push, tag, deployment, or gem publication is included in this task. Task-owned
temporary servers and browser sessions are stopped after verification. The next
planned development milestone is 0.9 stabilization after the 0.5 release gates.
