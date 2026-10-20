# 0.4.0 publication

Date: 2026-10-20. The owner authorized remote CI, publication acceptance, and
the corresponding documentation updates.

## Published artifact

- Source: tag `v0.4.0`, commit `02aeef59e64fbd6ed9ec87c733bf04e454386a75`.
- [RubyGems 0.4.0](https://rubygems.org/gems/openui-rails/versions/0.4.0),
  published at `2026-10-20T02:43:55.880Z` through GitHub OIDC.
- [GitHub Release](https://github.com/yorzi/openui-rails/releases/tag/v0.4.0),
  published at `2026-10-20T02:47:59Z`, with the gem and `SHA256SUMS` attached.
- Package size: 89,088 bytes; 79 packaged files. SHA-256:

  ```text
  faebc160f6addd7114b33f9b9738b750e20b0b5e3260413c3e66961cfae143b4
  ```

Every packaged file matches its source at the verified tag. The publication
workflow artifact, GitHub download and asset digest, attached `SHA256SUMS`,
RubyGems download, and RubyGems API checksum all match. The package excludes
fetched browser bundles, databases, credentials, and temporary test artifacts.
The earlier candidate checksum in [VALIDATION_0_4.md](VALIDATION_0_4.md) is
historical and does not identify this published artifact.

## Verification

| Gate | Result |
| --- | --- |
| [Main CI](https://github.com/yorzi/openui-rails/actions/runs/39359384954) | Complete CI passed for the exact tagged commit. |
| [Tag verification](https://github.com/yorzi/openui-rails/actions/runs/39359752177) | Complete reusable CI, strict release metadata, and packaging passed. |
| [Publication](https://github.com/yorzi/openui-rails/actions/runs/39360080094) | Complete CI passed again; the existing protected environment was approved under the owner's authorization; OIDC publication and release drafting passed. |
| Ruby/Rails matrix | Ruby 3.2, 3.3, and 3.4 with Rails 8.0 and 8.1: each 253 core tests and 722 assertions, with no failures, errors, or skips. |
| Reference transactions and HTTP | Each matrix combination passed 9 tests and 52 assertions. |
| RubyLLM 2.1.1 | Real SSE parser with mocked HTTP: 1 test and 7 assertions on each matrix combination. |
| Browser CI | 33 fixture-runtime tests and 109 assertions; 6 real-runtime tests and 34 assertions; 8 built-gem reference tests and 81 assertions. All passed without failures, errors, or skips. |
| Built-gem setup CI | Fresh host, optional migration, separate-process false replay, real rendering, CSRF action, and mobile layout passed. |
| Public RubyGems download | Isolated temporary gem installation and require passed; a fresh host passed setup and real rendering; the reference browser suite passed 8 tests and 81 assertions with no failures, errors, or skips. |
| Dependencies and style | GitHub security and lint jobs passed. |
| Local release verification | Full `bin/check --runtime tmp/real-runtime --docs` passed. Post-tag stable 0.4 and next builds passed; 22 guides linted without errors or warnings; 1,854 guide links and anchors passed. |

SQLite checks cover independent-process competition for new and expired keys,
durable replay including `nil` and `false`, request digest mismatch, trusted
actor and tenant scope, abandoned claims, cleanup, and stale-writer fencing.
The reference uses the shared store and retains its business receipt constraint.
Desktop and 390px mobile screenshots from the public-gem run were inspected.
Browser emulation does not establish physical-device support.

The first standalone installation probe misidentified macOS `/var` and
`/private/var` aliases as different paths. The final probe compares real paths
and verifies the temporary installation. Package checks reuse cached dependencies;
they do not prove every possible dependency resolution or external adoption.
No live-provider call was made for 0.4.0; generation remains recorded in CI.

## Documentation deployment

The [release-triggered deployment](https://github.com/yorzi/openui-rails/actions/runs/39360863775)
built stable 0.4.0 and `/next/` from `main`.

The job completed successfully, but HTTP and a fresh browser still showed
stable 0.3.0, and the new stable What's New page returned 404. This is not a
successful hosted-version check. The release record and README changes
in commit `92f3c27` triggered a
[fresh successful deployment](https://github.com/yorzi/openui-rails/actions/runs/39361111791).
Subsequent HTTP checks and a real-browser reload confirmed stable 0.4.0 in the
version selector and `bundle add openui-rails --version 0.4.0` in Getting Started.
The browser screenshot also shows What's New in 0.4 and the installation command.

All 14 hosted checks returned HTTP 200 with the expected contents:

- Stable Getting Started, Upgrading, What's New in 0.4, and Release History.
- Shared Idempotency Storage, Reference Workflow, and Setup Diagnostics.
- The generated ActiveRecordStore API, including claim, record, and cleanup.
- Next Getting Started, Upgrading, and Shared Idempotency Storage, following main.
- Stable and next `llms.txt`, plus the sitemap and the new release's links.

The hosted assertion uses Getting Started's actual `bundle add` command; its
earlier expectation of Gemfile syntax was corrected without changing the guide.
Raw checks and reference screenshots remain ignored under `tmp/evidence` and
`tmp/browser`. Task-owned browser tabs, sessions, and temporary services were
stopped after verification.

The README, changelog, What's New, upgrade guide, release history, API links,
shared-storage guide, and roadmap reflect the delivered scope. Candidate
validation remains a historical record. Documentation-only follow-ups do not
change the release tag or published gem.

## Supported boundary

Shared storage is opt-in; memory remains the default. The supported database
evidence covers SQLite on one machine with a shared persistent file. PostgreSQL,
Redis, network filesystems, and multi-machine SQLite are not verified. Expiry
uses synchronized wall clocks without lease renewal. JSON object keys become
strings on replay, and calls participate in surrounding database transactions.

A shared claim does not provide exactly-once business effects. Keep operation
uniqueness or receipts and external-effect idempotency or reconciliation for
TTL overlap and the commit-before-record crash window. See
[Shared Idempotency Storage](https://openui-rails.wangyaodi.com/shared-idempotency/).
The next proposed milestone is 0.5 diagnostics and recovery, as scoped in
[ROADMAP.md](ROADMAP.md).
