# Changelog

All notable changes to `openui-rails` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed during pre-publication audit

- Scope idempotency to server actor/tenant identity and bind replay digests to
  the full request. Distinguish pending claims from completed nil results and
  fence expired writers with claim tokens.
- Preserve host authentication filters and default current-user resolution.
- Canonicalize and copy JSON input before validation/fingerprinting; prevent
  mutable submissions, envelopes, surfaces, and manifests.
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

[Unreleased]: https://github.com/yorzi/openui-rails/commits/main
