# Pre-release audit changes

These changes apply before the first published release.

- Custom idempotency stores must distinguish `:pending` from completed
  `:replay`, return a claim token, and accept `record(..., claim_token:)`.
  See [CONFIGURATION.md](CONFIGURATION.md).
- Action arguments are canonical JSON copies with string keys. Submissions,
  surfaces, envelopes, and manifests no longer share mutable caller input.
- The engine controller inherits the host's `ApplicationController` and
  preserves its authentication filters. Full-stack Rails controllers are
  required. API-only controllers need a host-owned HTML/session/CSRF boundary;
  that integration is not covered by this release.
- The helper rejects a persisted surface whose library differs from the
  configured manifest. The browser verifies the actual runtime `toSpec()`.
  Custom prompt/spec files require a matching custom runtime, not the default
  chat bundle.
- Add `<%= openui_stylesheet_tag %>` once in your layout. The runtime fetch task
  now installs checksum-verified JS, CSS, and the upstream license.
- The RubyLLM adapter no longer passes a question argument to `Chat#complete`.
  It adds the user message first. Both `:complete` and `:ask` work with 2.1.1.
- Completion and error frames participate in sequence validation. After a gap,
  all deltas pause until the host sends a current snapshot. Duplicate finishes
  and writes after a terminal writer state produce no additional frames.
- Tag pushes verify and build a release artifact. Publication now requires an
  explicit manual workflow dispatch after the full CI suite succeeds.
