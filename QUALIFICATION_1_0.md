# Qualification for 1.0

Date: 2026-10-28. This record covers the unpublished 0.9.1 stabilization
candidate. It is a release-readiness baseline, not a 1.0 release or a claim
that the candidate passed remote CI. Published 0.9.0 evidence remains in
[RELEASE_0_9.md](RELEASE_0_9.md).

## Delivered preparation

- `bin/demo` builds the gem and starts a disposable Support Desk host on
  loopback. Its landing page explains the workflow and the three synthetic
  accounts. Stopping the foreground server removes the new host and database.
- The reference enforces nonce-authorized scripts, rejects untrusted inline
  scripts, and retains the inline styles required by runtime 0.2.1. Browser
  tests cover Tab navigation through the generated form and Enter activation.
- `bin/check-host` creates an independent Rails consumer with its own SQLite
  record, view, action, and authorization. It uses public tasks and APIs and
  loads neither `test/dummy` nor the packaged Support Desk application.
- The normal independent-host path and the offline single-request live-command
  tests run in `bin/check` and are wired into CI. CI never runs paid generation.
  The optional historical upgrade path requires an explicitly supplied gem.
- Local working materials belong to ignored `drafts/`; RuboCop excludes that
  directory. Runtime pins, public gem APIs, migrations, and declared runtime
  dependencies are unchanged.

## Local verification

Ruby 3.3.5; SQLite; Chrome through Selenium; checksum-locked runtime 0.2.1.
Database-backed checks ran sequentially. Each Rails line completed
`bin/check --runtime tmp/real-runtime --docs`.

| Check | Rails 8.1.4 / JSON 3.1.0 | Rails 8.0.5.1 / JSON 2.21.2 |
| --- | --- | --- |
| Core | 264 tests, 793 assertions | 264 tests, 793 assertions |
| RubyLLM SSE compatibility, mocked HTTP | 2 tests, 11 assertions | 2 tests, 11 assertions |
| Live-command success/failure and retry limits, mocked HTTP | 2 tests, 13 assertions | 2 tests, 13 assertions |
| Reference transactions and HTTP | 9 tests, 52 assertions | 9 tests, 52 assertions |
| Fixture browser bridge | 39 tests, 142 assertions | 39 tests, 142 assertions |
| Pinned real-runtime compatibility | 6 tests, 34 assertions | 6 tests, 34 assertions |
| Built-gem reference browser | 16 tests, 165 assertions | 16 tests, 165 assertions |
| Built-gem setup and independent public host | Passed | Passed |

All listed tests passed without failures, errors, or skips. The built-gem
setup also checks installation, library preparation, doctor, optional shared
storage, independent-process replay, real rendering, CSRF action, and mobile
layout. RuboCop reports 147 maintained Ruby files without offenses; the new
extensionless tools also pass focused lint. Workflow YAML parses locally.

The final local archive has 80 files and is 95,744 bytes, SHA-256
`8f3a5c7bb0d0e5f3f5decc17696240644ab937bf5649789055d46c6c7c431a38`.
Every packaged source file matches the prepared working tree. The final rebuild
adds the last documentation edits; packaged executable files are unchanged from
the archives exercised above. This is not a published-artifact checksum.

Stable 0.9.0 and next candidate documentation builds passed. The 26 guides
lint without errors; the two warnings identify the expected unpublished
candidate. All 2,430 generated guide links and anchors resolve. New CSP,
keyboard, live-output, and demo screenshots were inspected.

The demo lifecycle probe checks HTTP startup, an enforced CSP header, graceful
TERM shutdown, deletion of its temporary host, and closure of its listening
port. Task-owned services and browsers stop after checks.

## Real provider and upgrade rehearsal

The owner explicitly authorized one synthetic OpenRouter request with
`openai/gpt-4.1-mini`, at most 1024 output tokens, and a US$0.25 budget. The
command disables SDK retries and provider fallbacks. Its price preflight uses
the [official model metadata](https://openrouter.ai/api/v1/models).

That single request used RubyLLM 2.1.1 and completed with `finish_reason: stop`:
6,529 input tokens, 26 output tokens, 108 source bytes, and three ordered stream
frames. Its conservative token-cost bound was US$0.0142952; token-based cost is
approximately US$0.0026532. The billed charge was not checked.

The unchanged model output rendered in the independent Rails consumer, and
its keyboard-activated, authorized action persisted one effect. Generation
streamed through the adapter; the browser subsequently rendered its persisted
canonical output. This does not establish concurrent live browser delivery,
other providers, model reliability, or external adoption.

The published 0.1.0 download was verified against its RubyGems API SHA-256:
`275c124a9e8e9c82b471357e3f314e4c86d6255c8fc9ef0313be858525bffee5`.
The same host and SQLite database then booted 0.1.0, the 0.9.1 candidate, and
0.1.0 again. The model-generated response, library fingerprint, draft, and
effect counter survived. Each stage executed one authorized action, advancing
the counter from zero to three. Candidate library mismatch produced HTML
fallback without deleting canonical records. The three stages passed 33
assertions in total.

Integration friction was real: a handler that requires forwarded conversation
metadata rejects the empty arguments emitted by 0.1. The rehearsal host
explicitly accepts both documented shapes to permit rollback. Support Desk
first appeared in 0.3, so this rehearsal uses a 0.1-compatible consumer rather
than claiming that the later reference application existed in 0.1.

## Security and reviewed limits

The refreshed advisory database found Crass 1.0.7 in the local Rails dependency
lockfile. It was updated to 1.0.8, and the final root dependency audit passes.
The affected functional suites were rerun after the update. See the
[upstream advisory](https://github.com/rgrove/crass/security/advisories/GHSA-pq4g-8rxf-4g29).
The repository does not track its development lockfile; application owners must
update and audit their own locked dependencies. No advisory was suppressed.

The exact runtime's embedded notices and manifest were reviewed and the
identified groups recorded in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
The manifest contains dependency ranges, not a complete resolved inventory.
The gem does not redistribute the bundle; hosts that do still need that
inventory. No legal clearance is inferred from retained comments.

The verified script CSP still permits inline styles. Keyboard, form names,
status/error regions, native fallback, and mobile layout have evidence;
screen-reader announcements and full WCAG conformance do not. These limits are
documented in the site's Production Considerations guide.

## Remaining release work

1. Remove the already-deprecated `library_name` and `surface_id_param` settings
   at the 1.0 boundary, with corresponding tests and upgrading instructions.
   They stay compatible in this 0.9.1 patch candidate.
2. Prepare the exact final candidate and run its complete remote Ruby/Rails
   matrix, dependency audit, browser and built-gem checks. Current local evidence
   uses Ruby 3.3; it does not establish current Ruby 3.2, 3.4, or 4.0 success.
3. Obtain release authorization, then complete the tag, protected publication,
   public download/checksum/install, GitHub Release, and hosted stable/next
   acceptance in [RELEASING.md](RELEASING.md).

Do not add unrelated features to fill the remaining version numbers. Fix
qualification defects in 0.9.x and rerun their affected checks. Local optional
materials are under `drafts/qualification-2026-10-28/`; automated browser
artifacts are ignored under `tmp/browser/`. Neither is required by the gem or CI.
