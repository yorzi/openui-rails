# Changelog

All notable changes to `openui-rails` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.4.0] - 2026-10-20

### Added

- Optional `Actions::Idempotency::ActiveRecordStore` with atomic database claims,
  ownership fencing, JSON result persistence, and explicit expiry cleanup.
  SQLite is the verified database; memory remains the default.
- `openui:idempotency` generates the opt-in table and its unique key and expiry
  indexes. Installing the engine alone creates no shared-store table.
- Reusable Minitest store-conformance checks, independent-process SQLite tests,
  and a fresh-host migration and restart check against the built gem.

### Changed

- The support-desk reference uses the shared store while retaining its business
  uniqueness constraint. A shared claim does not guarantee exactly-once effects.

## [0.3.0] - 2026-10-19

### Added

- A packaged, opt-in support-ticket reference host with SQLite persistence,
  importmap, HTTP Turbo Streams, real Query/Mutation calls, host-owned
  conversation continuation, and scoped snapshot recovery.
- `bin/check-reference` verifies the maintained host or a fresh host using only
  the built artifact. Browser checks cover reload, lost envelopes, expired
  identity, cross-tenant access, read-only roles, stale/duplicate actions, CSRF,
  keyboard activation, and mobile layout. The reference host enables CSRF
  itself, including during the documented test-environment review session.
- `bin/check-release --candidate` validates unpublished candidate metadata
  without weakening the publication gate.
- `Surface` and `openui_surface` accept persisted `next_sequence` and
  `completed` values to restore stream ordering after a page reload.

### Fixed

- Conversation actions preserve the official runtime's user message, form name,
  and form state as validated-by-host action arguments. Strict
  `continue_conversation` schemas need to allow the metadata they consume.

## [0.2.0] - 2026-10-18

### Added

- `openui:library:prepare` installs prompt/spec exports of the exact pinned
  default chat library and its upstream license without browser or Node tools.
  Existing different files require explicit overwrite; outputs stay inside
  the application root.
- `openui:doctor` reports local configuration, default library identity,
  runtime checksums, and action-route failures without writes or network calls.
  Browser setup and host policy checks remain explicitly unverified.
- Local `bin/check` and disposable `bin/check-browser` runners, with fixture
  screenshots on both passing and failing tests and the same browser entry
  point in CI.

### Changed

- The install generator leads with the default chat library and setup checks.
  Custom libraries retain the pinned CLI path and require a matching runtime.

### Fixed

- Manifest name queries now read name-keyed collections used by the official
  default-library spec, as well as the previously supported array format.
  Fingerprint calculation is unchanged.

## [0.1.0] - 2026-10-18

### Fixed

- Scope idempotency to server actor/tenant identity and bind replay digests to
  the full request. Distinguish pending claims from completed nil results and
  fence expired writers with claim tokens.
- Preserve host authentication filters and default current-user resolution.
- Reject authentication redirects and malformed or mismatched action responses
  instead of reporting a false success.
- Canonicalize and copy JSON input before validation/fingerprinting; prevent
  mutable submissions, envelopes, surfaces, and manifests.
- Make explicit configuration readiness validation read the actual manifest
  and prompt files instead of accepting filenames alone.
- Enforce stream terminal states, completion ordering, snapshot watermarks,
  browser byte limits, and Turbo cache restoration.
- Use the real OpenUI `{type, params}` action contract, avoid false MCP-client
  detection, return raw tool values, and ignore empty renderer-error arrays.
- Verify configured library fingerprints against the actual runtime `toSpec()`.
- Fetch exact checksum-locked JS/CSS/license files without npm lifecycle scripts.
  Add `openui_stylesheet_tag` and default integrity pins.
- Correct RubyLLM's block-only `complete` call and verify 2.1.1 with real SSE parsing.
- Align message framing edge cases with lang-core 1.0.1.
- Require full CI and explicit manual approval before publication; create a
  genuine draft GitHub release. See `UPGRADING.md` for pre-release changes.

### Added

- Mountable Rails engine under the `OpenUI::Rails` namespace with the
  `openui/rails` require path.
- Configuration object with validated transport, runtime-asset strategy,
  library/prompt paths, stream limits and action hooks.
- Versioned component-library manifest with a canonical SHA-256 fingerprint.
- Prompt builder tying the model system instruction to the exact library
  revision and stamping a combined prompt fingerprint.
- Ruby implementation of the upstream OpenUI message protocol
  (`build`/`parse`/`strip`).
- Ordered stream envelopes (`openui.delta/snapshot/completed/error`), a
  sequence accumulator and a coalescing stream bridge/writer.
- Server-authoritative action loop: allowlist registry, arg schema,
  confirmation, stale-surface check, required authorizer and idempotency.
- `openui_surface` view helper and the `OpenUI::Rails::ActionsController`
  endpoint.
- Optional RubyLLM adapter (no hard dependency).
- Stimulus mount controller and pinned runtime-asset resolution.
- `openui:install` generator and the `openui:runtime:fetch` task.
- Transport broadcasters (`ActionCable`, `TurboStreams`, `Memory`) behind
  `Stream::Broadcaster`, and the `openui-envelope` Stimulus controller that
  turns a Turbo Stream append into an `openui:envelope` event without inline
  script.
- Browser (system) test suite: lifecycle, stream ordering/duplicate/gap,
  snapshot recovery, completion/error, action/tool round-trips, destructive
  confirmation, and mount accessibility (`aria-busy` lifecycle, named region).
- `aria-busy` on the mount element tracks the streaming state, and an optional
  `label:` exposes the mount as a named `region` landmark.
- Tag-driven release workflow and `RELEASING.md`.
- Versioned guides and an RDoc API reference at
  `https://openui-rails.wangyaodi.com`, deployed with GitHub Pages.
- Gem-scoped RubyGems Trusted Publishing through GitHub OIDC, with a protected
  release environment and verified artifact handoff.

[Unreleased]: https://github.com/yorzi/openui-rails/compare/v0.4.0...main
[0.4.0]: https://github.com/yorzi/openui-rails/releases/tag/v0.4.0
[0.3.0]: https://github.com/yorzi/openui-rails/releases/tag/v0.3.0
[0.2.0]: https://github.com/yorzi/openui-rails/releases/tag/v0.2.0
[0.1.0]: https://github.com/yorzi/openui-rails/releases/tag/v0.1.0
