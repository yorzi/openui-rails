# Pre-publication audit: 2026-10-18

## Outcome

The audit found real defects despite the original green test suite. The fixes
below have regression coverage. The owner authorized publication of `0.1.0`
on 2026-10-18. The exact tag's complete CI and protected publishing workflow
passed, and `0.1.0` is published on RubyGems and GitHub. This audit establishes
the specific behaviors below, not the absence of all bugs.

## Publication evidence

- Release tag `v0.1.0` points to commit
  `e2203c0e0f573f1b8206d9abdac4ab8f838594b8`.
- [Publishing run 39115168826](https://github.com/yorzi/openui-rails/actions/runs/39115168826)
  passed the complete reusable CI suite, package checks, protected environment
  approval, RubyGems upload, and GitHub release draft creation.
- [RubyGems 0.1.0](https://rubygems.org/gems/openui-rails/versions/0.1.0) and
  [GitHub Release v0.1.0](https://github.com/yorzi/openui-rails/releases/tag/v0.1.0)
  expose the same artifact. SHA-256:
  `275c124a9e8e9c82b471357e3f314e4c86d6255c8fc9ef0313be858525bffee5`.
  The actual RubyGems download, GitHub asset, API digest, and `SHA256SUMS` match.
- The downloaded RubyGems artifact passed the fresh Rails host probe: install
  generator, eager load, and HTTP rendering.
- [Documentation](https://openui-rails.wangyaodi.com/) uses GitHub Pages with
  Actions. Cloudflare has a DNS-only CNAME to `yorzi.github.io`. GitHub verified
  domain ownership through a TXT record and issued the certificate. HTTPS is
  enforced. The release docs build checks stable and `/next/` channels.

## Confirmed defects corrected

| Area | Defect | Correction and evidence |
| --- | --- | --- |
| Identity isolation | A client idempotency key could replay another actor's result or a different action's result. | Actor/tenant-scoped keys; request digest binds action, surface, revision, args, and confirmation. Cross-actor/action/surface/tenant regression tests. |
| Canonical input | Symbol-keyed and nested arguments had incorrect digests; mutable input could change after validation. | Deep canonical JSON copies and immutable data. Mutation and nested-digest tests. |
| Claim state | A completed `nil` looked pending; an expired writer could overwrite a newer claim. | Explicit pending/replay states and per-claim tokens. Nil/false, expiry, and concurrent-claim tests. |
| Host authentication | Engine controllers bypassed the host ApplicationController; documented default actor resolution was absent. | Host controller inheritance, explicit CSRF protection, current-user fallback, and tenant-swap tests. |
| Action responses | Authentication redirects, malformed JSON, or unrelated result objects could appear successful. | Reject redirects and non-JSON/malformed/mismatched responses; browser regression tests. |
| Stream ordering | Completion skipped missing deltas; stale snapshots rewound state; a gap did not pause later deltas. | Sequence gates for terminal frames and snapshots; Ruby/browser regressions. |
| Terminal writers | Duplicate finishes and writes after errors emitted more frames. | One terminal state. Consumer/transport failures propagate instead of being relabelled provider failures. |
| Browser lifecycle | Pre-load frames could render without a runtime; reconnect/cache restoration lost source or sequence state. | Deferred rendering, connection tokens, state preservation, real Turbo visit/back tests. |
| OpenUI actions | The stub used `{action,args}`, but the real runtime emits `{type,params}`. | Official event normalization, verified with a real component and keyboard activation. |
| Browser tools | The proxy looked like an MCP client and returned the endpoint wrapper instead of the handler value. | Reserved-property handling, stable provider identity, raw tool values. Real Query and Mutation tests. |
| Renderer errors | The official renderer calls `onError([])` after successful parsing. | Empty error arrays are ignored; actual error arrays become structured renderer errors. |
| Library identity | A fingerprint existed, but the runtime library was not checked. | Server rejects persisted mismatches; browser hashes `toSpec()` before mounting. Real-bundle and negative tests. |
| Runtime supply | Fetch chose the largest JS file, ran without checksum verification, and CSS was not integrated. | Exact file allowlist, committed archive/file hashes, npm scripts disabled, no archive path extraction, stylesheet helper. Real fetch and SRI-backed browser tests. |
| RubyLLM | `Chat#complete(question)` does not exist in RubyLLM 2.1.1. | Add the user message, then call block-only complete; verify both strategies through real provider SSE parsing with mocked HTTP. |
| Message framing | CRLF, malformed markers, post-end text, and multi-line raw context differed from lang-core. | Align framing with pinned lang-core 1.0.1 and extend regression cases. No Ruby DSL parser added. |
| Packaging | Standalone require needed Rails preloaded; previous smoke checks only installed the gem. | Explicit framework loading; a fresh host uses the extracted built artifact, generator, eager load, and an HTTP render. |
| Configuration readiness | A configured filename could pass validation without an actual valid manifest or prompt file. | Explicit readiness validation reads the files and clears stale derived state. Missing-file regression tests. |
| Release workflow | A tag could publish without running tests; the supposed draft was public; environment protection was only a comment. | Reusable full CI gate, explicit manual publish, artifact handoff, real draft flag, and documented reviewer setup. |

## Verification evidence

Local environment: Ruby 3.3.5, Rails 8.1.4, Chrome through Selenium.

- Unit/integration: `209 runs, 542 assertions`, no failures or errors.
- Deterministic browser suite: `32 runs, 104 assertions`, no failures or errors.
- Real `@openuidev/browser-bundle` 0.2.1: `5 runs, 30 assertions`, no failures or errors.
  Includes matching runtime/spec identity, rendering, keyboard action, Query,
  click-triggered Mutation, and unknown-component rejection.
- Real Turbo Streams broadcast over Action Cable, plus Turbo visit/back restoration.
- RubyLLM 2.1.1 with real OpenAI chat-completions SSE parsing and mocked HTTP:
  `1 run, 7 assertions`, no failures or errors. The deterministic test made no
  paid provider calls.
- Live-provider smoke (2026-10-18): one synthetic prompt streamed through the
  gem adapter with RubyLLM 2.1.1, OpenRouter, `openai/gpt-4.1-mini`, and the
  `:complete` strategy. A 16-token output cap was set. The first sandboxed
  attempt returned `stream_failed` with no delta; the network-enabled retry
  emitted one 2-byte delta and a completed frame. The account's usage ledger
  and exact charge were not checked. Evidence is limited to this OpenRouter
  path/model; direct OpenAI and other provider/model paths remain unverified.
- Checksum-locked npm runtime fetch, including CSS and upstream license: passed.
- Built artifact in a fresh generated Rails host: generator, eager load, and HTTP render passed.
- RuboCop: clean. JS syntax checks: passed.
- GitHub workflows: actionlint 1.7.12 passed. External actions are pinned to
  verified full commit SHAs, not mutable major-version tags.
- `bundler-audit check --update`: no known Ruby vulnerabilities at advisory DB
  commit `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485` (updated 2026-10-17).
- CI additionally checks Ruby 3.2/3.3/3.4 with Rails 8.0/8.1. Consult the
  linked repository workflow for the result of the latest audit commit.

Tests establish these specific behaviors, not universal provider compatibility,
complete accessibility, legal clearance, or an absence of future vulnerabilities.

## Release setup on 2026-10-18

- The owner explicitly authorized publication, public repository visibility,
  and RubyGems OIDC trust for `yorzi/openui-rails`, `release.yml`, environment
  `release`.
- The repository is public. Security reports go to the address in `SECURITY.md`;
  public support uses GitHub Issues.
- RubyGems Trusted Publishing for the exact workflow and environment was
  successfully used for the first release. The public version page identifies
  the GitHub Actions repository, workflow, and environment as its publisher.
- The GitHub `release` environment requires approval by `yorzi`, allows the
  `main` branch only, and disallows administrator bypass. Self-review remains
  available for the single maintainer.
- Dated `0.1.0` notes are in `CHANGELOG.md`. Gem and documentation versions
  are checked together before packaging.
- The built gem excludes the upstream browser bundle. A host that redistributes
  the fetched bundle must review its transitive notices, including ISC-licensed
  `lucide-react`. The gem's fetch task retains upstream legal comments and the
  upstream license file. This is not a legal-clearance claim.

## Boundaries hosts must enforce

- Shared atomic idempotency storage for multiple processes. TTL expiry, crashes,
  and irreversible effects still need database constraints or transactions.
- Trusted confirmation UI and, where needed, signed server approvals. A client
  boolean is not proof of human intent.
- Authorized stream subscriptions, scoped surface lookup, and authoritative
  snapshot persistence/recovery. The gem supplies no snapshot server.
- Request/body/rate limits and provider token/time budgets.
- A compatible prompt/spec/runtime library. The default bundle contains only
  the chat library; custom libraries require a matching runtime.
- CSP validation for the upstream renderer's inline styles. No strict-style-CSP
  support is claimed. No human screen-reader certification is claimed.
- API-only Rails authentication/CSRF integration is not covered by this release.

The owner's publication authorization is not an independent legal, security,
or accessibility certification. Follow [RELEASING.md](RELEASING.md) for each release.
