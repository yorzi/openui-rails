# Changelog

All notable changes to `openui-rails` are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project
adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
  snapshot recovery, completion/error, and action/tool round-trips.
- Tag-driven release workflow and `RELEASING.md`.

[Unreleased]: https://github.com/yorzi/openui-rails/commits/main
