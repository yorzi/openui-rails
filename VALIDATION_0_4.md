# 0.4.0 local candidate validation

Date: 2026-10-20. Version 0.4.0 is an unpublished development candidate.
This record covers local implementation and verification. It does not establish
remote CI, hosted documentation, RubyGems publication, or live-provider success.
Implementation commit: `e574fb0`.

## Delivered scope

- Optional `Actions::Idempotency::ActiveRecordStore` using SQLite, a unique key
  index, atomic insert or expired-row replacement, and ownership tokens.
- JSON result persistence across workers and restarts, including completed
  `nil` and `false`; explicit `delete_expired` cleanup without a scheduler.
- Opt-in `openui:idempotency` migration generator. The base installer creates
  no shared-store table, and `MemoryStore` remains the default.
- Reusable Minitest store contract, real independent-process competition tests,
  and built-gem migration and restart checks in a disposable Rails host.
- The support-desk reference opts into shared storage and retains its unique
  business receipt. The maintained dummy consumes the generator's exact schema.
- Shared-storage, configuration, API, upgrade, and What's New guides. Stable
  documentation remains at 0.3.0; working-tree documentation is the 0.4 candidate.

## Verified locally

Database-backed suites ran sequentially. Ruby is 3.3.5; both bundles use sqlite3
2.10.0 with SQLite 3.54.0. Browser checks use the pinned OpenUI runtime 0.2.1.

| Check | Result |
| --- | --- |
| Rails 8.1.4 / JSON 3.1.0 core suite | 253 tests, 722 assertions, no failures, errors, or skips. |
| Rails 8.0.5.1 / JSON 2.21.2 core suite | 253 tests, 722 assertions, no failures, errors, or skips. |
| RubyLLM 2.1.1 SSE parser with mocked HTTP | 1 test, 7 assertions on each Rails line, passed. |
| Reference transactions and HTTP boundaries | 9 tests, 52 assertions on each Rails line, passed. |
| Browser bridge with fixture runtime | 33 tests, 109 assertions on each Rails line, passed. |
| Real pinned browser runtime | 6 tests, 34 assertions on each Rails line, passed. |
| Final built-gem setup | Fresh host, default installation, opt-in migration, separate-process false replay, unique index, library setup, doctor, real rendering, CSRF action, and mobile layout passed on each Rails line. |
| Final built-gem reference workflow | 8 browser tests, 81 assertions on each Rails line, passed using the shared store and extracted application code. |
| Style | 142 Ruby files inspected, no offenses. Rails-generated schema formatting is excluded. |
| Documentation | Stable 0.3 and next 0.4 built; 22 guides have no lint errors; 1,729 generated guide links and anchors passed. |
| Advisory database | Refreshed at `fa2295251efb3b0d1a300e5ce8ad700ff1f1b485`; no known vulnerabilities found in the bundle. |
| Candidate metadata | `ruby bin/check-release --candidate` passed. Publication metadata remains intentionally incomplete. |

The store tests run the same contract against memory and SQLite. Four separate
Ruby VMs compete at a start barrier for both a new key and an expired key; each
round admits one owner. Other checks cover pending and completed results,
restart persistence, changed request digests, trusted actor and tenant scope,
expiry cleanup, abandoned claims, unsupported JSON values, and stale writers.

A generator regression test first reproduced a collision with Rails' inherited
`create_migration` method. The generator now uses `create_store_migration` and
repeated generation produces one migration. Package verification also exposed
inherited `DATABASE_URL` leaking into the generated host; the runner now assigns
its own temporary database. Rails 8.0 checks explicitly use the test environment.
The dummy schema is generated with migration compatibility 8.0 for both lines.

The sandbox denied ChromeDriver's loopback bind during an initial Rails 8.0
browser attempt. The same checks passed with local process permission. This was
an execution-environment failure, not a passing browser result.

Desktop and 390px mobile reference screenshots were visually inspected. Browser
assertions cover reload, dropped-envelope recovery, late-frame fencing, expired
identity, tenant boundaries, reader permissions, duplicate and stale actions,
keyboard activation, and CSRF. Emulation does not prove physical-device support.

## Final artifact

Artifact: `tmp/package/openui-rails-0.4.0.gem`, 89,088 bytes, 79 packaged files.
SHA-256:

```text
298a516a095fca7c58a9656ea5c9c573a0ffd364272eacc6f738ada4dc287e40
```

The final consumer checks on both Rails lines use these exact bytes. The package
contains the generator, store, conformance module, and reference host; it contains
no fetched browser runtime, database, nested gem, environment file, or temporary
test artifacts. Generated hosts and raw evidence remain ignored under `tmp/` or
task-owned temporary directories. Package checks use cached dependencies, not a
clean online installation or evidence of external adoption.

## Reproduce

```sh
bin/check --runtime tmp/real-runtime --docs
bin/check-reference --gem tmp/package/openui-rails-0.4.0.gem --runtime tmp/real-runtime
```

Fetch the pinned runtime explicitly first; see [DEVELOPMENT.md](DEVELOPMENT.md).
For the locally installed Rails 8.0 bundle, set `RAILS_ENV=test`,
`BUNDLE_GEMFILE` to its absolute Gemfile, and `RAILS_VERSION=8.0`. Run database
suites sequentially. Raw logs and screenshots are local evidence, not release
assets. Two documentation warnings are expected: version 0.4.0 differs from
v0.3.0, and `released: false` coexists with the published tag.

## Supported boundary and remaining gates

SQLite workers share one persistent database file on one machine. No PostgreSQL,
Redis, network-filesystem, or multi-machine SQLite compatibility is claimed.
Claims use synchronized wall clocks and expire from acquisition, without lease
renewal. Calls participate in any surrounding transaction on their connection.
JSON object keys become strings on replay; unsupported results fail after the
handler may already have committed an effect.

A worker can outlive its TTL, or stop after a business commit and before storing
its result. Token fencing prevents overwriting a replacement's result; it does
not undo effects or guarantee exactly-once execution. Keep a business operation
constraint or receipt and use external-effect idempotency or reconciliation.

- After an authorized push, require CI for the exact candidate, including Ruby
  3.2/3.3/3.4 with Rails 8.0/8.1. Only Ruby 3.3.5 was exercised locally.
- With publication authorization, date the changelog, mark the docs released,
  update installation and release-history metadata, and run the strict release
  gate. Follow [RELEASING.md](RELEASING.md) for tag, artifact, and hosted checks.
- Keep later work scoped to [ROADMAP.md](ROADMAP.md): 0.5 diagnostics and recovery,
  followed by stabilization. Additional backends need a real host requirement.

No push, tag, deployment, gem publication, or live-provider call is part of this
candidate task. Task-owned browser sessions and temporary services are stopped
after verification.
