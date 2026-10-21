# 0.5.0 publication

Date: 2026-10-21. The owner authorized release acceptance, publication, and
the corresponding documentation updates.

## Published artifact

- Source: tag `v0.5.0`, commit `d7b7abab5169b59c4976b1aff75a622744548364`.
- [RubyGems 0.5.0](https://rubygems.org/gems/openui-rails/versions/0.5.0),
  published at `2026-10-21T00:12:32.266Z` through GitHub OIDC.
- [GitHub Release](https://github.com/yorzi/openui-rails/releases/tag/v0.5.0),
  published at `2026-10-21T00:14:30Z`, with the gem and `SHA256SUMS` attached.
- Package size: 91,648 bytes; 80 packaged files. SHA-256:

  ```text
  511304634ba108cafeb278a414fa1400759928d60a38d8081cfbb28bc8cca710
  ```

Every packaged file matches its source at the verified tag. The publication
workflow artifact, guest GitHub download and asset digest, attached `SHA256SUMS`,
RubyGems download, and RubyGems API checksum all match. The package excludes
fetched browser bundles, databases, credentials, and temporary test artifacts.
The checksum in [VALIDATION_0_5.md](VALIDATION_0_5.md) identifies the earlier
candidate, not this published artifact. Documentation follow-ups do not move
the tag or change the published gem.

## Verification

| Gate | Result |
| --- | --- |
| [Main CI](https://github.com/yorzi/openui-rails/actions/runs/39518695824) | All 10 jobs passed for the exact tagged commit. |
| [Tag verification](https://github.com/yorzi/openui-rails/actions/runs/39519083739) | Complete reusable CI, strict release metadata, and packaging passed. |
| [Publication](https://github.com/yorzi/openui-rails/actions/runs/39519450095) | All 14 jobs passed, including complete CI, protected environment approval under the owner's authorization, OIDC publication, and release drafting. |
| Ruby/Rails matrix | Ruby 3.2, 3.3, and 3.4 with Rails 8.0 and 8.1: each 258 core tests and 772 assertions, with no failures, errors, or skips. |
| Reference transactions and HTTP | Each matrix combination passed 9 tests and 52 assertions. |
| RubyLLM 2.1.1 | Real SSE parser with mocked HTTP: 1 test and 7 assertions on each matrix combination. |
| Browser CI | 37 fixture-runtime tests and 131 assertions; 6 pinned real-runtime tests and 34 assertions; 14 built-gem reference tests and 144 assertions. All passed without failures, errors, or skips. |
| Built-gem setup CI | Fresh host, optional shared migration, separate-process false replay, real rendering, CSRF action, and mobile layout passed. |
| Public RubyGems download | Temporary isolated gem installation and require passed. A fresh host passed setup and real rendering. The reference browser suite passed 14 tests and 144 assertions without failures, errors, or skips. |
| Dependencies and style | GitHub security and lint jobs passed. Local advisory refresh found no known vulnerabilities; RuboCop inspected 144 files without offenses. |
| Local release verification | Full `bin/check --runtime tmp/real-runtime --docs` passed on Ruby 3.3.5 and Rails 8.1.4. Post-tag stable 0.5 and next builds passed; 24 guides linted without errors or warnings; 2,128 guide links and anchors passed. |

Recovery checks cover runtime load failure, library mismatch, provider failure,
stream limits, sequence gaps, explicit snapshot read retry, stale actions, and
session expiry. Late action responses, disconnected renderer callbacks, late
snapshots after permission failure, and Turbo restoration have assertions.
Diagnostic tests check bounded payloads and subscriber failures. The reference
never automatically retries a mutation after an unknown result.

Desktop and 390px mobile fallback screenshots from the public-gem run were
inspected. Browser emulation does not establish physical-device support.
Package checks reuse cached dependencies and do not prove every possible
dependency resolution or external adoption. No live-provider call was made for
0.5.0; generation remains recorded in CI.

## Documentation deployment

The [release-triggered deployment](https://github.com/yorzi/openui-rails/actions/runs/39520116261)
completed successfully and built stable 0.5.0 plus next from `main`. Actual HTTP
checks still returned the previous stable installation and upgrade guides;
the new What's New and Diagnostics and Recovery pages returned 404. Next
already served the new recovery guide. This is not a successful hosted-version
check. Commit `17d915e` triggered a
[fresh deployment](https://github.com/yorzi/openui-rails/actions/runs/39520380280).
HTTP and a fresh browser reload then confirmed stable 0.5.0, its installation
command, and the new guides.

One API check exposed a separate build defect: the runner's default RDoc 6.6.3.1
silently omitted `Dispatcher#call` and the other methods after its `Struct`
block. Local reproduction confirmed the omission; local RDoc 8.1.0 included
them. The docs bundle now locks RDoc 8.1, the API builder uses that bundle, and
a missing `Dispatcher#call` anchor fails the build. This changes documentation
tooling, not the published gem. Final hosted API acceptance remains pending.

## Supported boundary and next step

Server diagnostics omit application content and identify operation outcomes.
Stream termination describes frame creation, not browser delivery. Browser
event payloads can contain application data and require host-controlled logging.
Ready and snapshot-applied events do not promise a successful render.

Rails still owns identity, tenant scope, canonical snapshots, recovery controls,
and business integrity. Keep database constraints and receipts for uncertain
mutations. The next proposed milestone is 0.9 stabilization: clarify and freeze
public contracts, qualify an external host integration, rehearse upgrades and
rollback, and complete the separately authorized live-provider workflow in
[ROADMAP.md](ROADMAP.md). Passing 0.5 does not satisfy those 1.0 gates.
