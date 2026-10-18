# Pre-publication audit: 2026-10-18

## Outcome

The audit found real defects despite the original green test suite. The fixes
below have regression coverage. The gem is a verified **release candidate**,
not an approved or published release. No audit can establish the absence of all
bugs, and the human publication gates remain open.

## Confirmed defects corrected

| Area | Defect | Correction and evidence |
| --- | --- | --- |
| Identity isolation | A client idempotency key could replay another actor's result or a different action's result. | Actor/tenant-scoped keys; request digest binds action, surface, revision, args, and confirmation. Cross-actor/action/surface/tenant regression tests. |
| Canonical input | Symbol-keyed and nested arguments had incorrect digests; mutable input could change after validation. | Deep canonical JSON copies and immutable data. Mutation and nested-digest tests. |
| Claim state | A completed `nil` looked pending; an expired writer could overwrite a newer claim. | Explicit pending/replay states and per-claim tokens. Nil/false, expiry, and concurrent-claim tests. |
| Host authentication | Engine controllers bypassed the host ApplicationController; documented default actor resolution was absent. | Host controller inheritance, explicit CSRF protection, current-user fallback, and tenant-swap tests. |
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
| Release workflow | A tag could publish without running tests; the supposed draft was public; environment protection was only a comment. | Reusable full CI gate, explicit manual publish, artifact handoff, real draft flag, and documented reviewer setup. |

## Verification evidence

Local environment: Ruby 3.3.5, Rails 8.1.4, Chrome through Selenium.

- Unit/integration: `208 runs, 539 assertions`, no failures or errors.
- Deterministic browser suite: `30 runs, 93 assertions`, no failures or errors.
- Real `@openuidev/browser-bundle` 0.2.1: `5 runs, 30 assertions`, no failures or errors.
  Includes matching runtime/spec identity, rendering, keyboard action, Query,
  click-triggered Mutation, and unknown-component rejection.
- Real Turbo Streams broadcast over Action Cable, plus Turbo visit/back restoration.
- RubyLLM 2.1.1 with real OpenAI chat-completions SSE parsing and mocked HTTP:
  `1 run, 7 assertions`, no failures or errors. No paid provider was called.
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

## Publication gates still open

1. Owner approval of name/branding and the complete transitive browser notice
   inventory. The previous all-MIT assumption was wrong: lucide-react is ISC.
2. One authorized, budget-capped live-provider smoke run. None was performed;
   mocked HTTP does not validate credentials, billing, or live provider behavior.
3. Dated release notes and final owner approval. The version remains 0.1.0 with
   unreleased notes; `bin/check-release` deliberately rejects publication metadata.
4. GitHub release environment reviewers, RubyGems credentials, and repository
   visibility/support decisions. The audit found no configured environments or
   repository secrets. It did not add any or change repository visibility.

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

Do not describe this candidate as bug-free or human-approved. Follow
[RELEASING.md](RELEASING.md) before publishing.
