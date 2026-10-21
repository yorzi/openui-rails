# 0.9.0 publication

Date: 2026-10-21. The owner authorized the release and approved the protected
`release` environment for the publication run.

## Published artifact

- Source: tag `v0.9.0`, commit `60c94f8`.
- [RubyGems 0.9.0](https://rubygems.org/gems/openui-rails/versions/0.9.0),
  published at `2026-10-21T01:20:14.680Z` through GitHub OIDC.
- [GitHub Release](https://github.com/yorzi/openui-rails/releases/tag/v0.9.0),
  published at `2026-10-21T01:22:52Z`, with the gem and `SHA256SUMS` attached.
- Package size: 93,696 bytes; 80 packaged files. SHA-256:

  ```text
  2e2d30d6919cf7f88650124c55e4a5f7890d244d1f4ef32f5dcd0c2c25a8e94a
  ```

The RubyGems API checksum, the RubyGems download, the GitHub release asset and
its digest, the attached `SHA256SUMS`, and the publication workflow artifact all
match. Every packaged file is byte-identical to its source at `v0.9.0`. The
checksums in [VALIDATION_0_9.md](VALIDATION_0_9.md) identify earlier local
candidate builds, not this artifact.

## Verification

| Gate | Result |
| --- | --- |
| [Main CI](https://github.com/yorzi/openui-rails/actions/runs/39525494936) | All 10 jobs passed for the exact tagged commit. |
| [Tag verification](https://github.com/yorzi/openui-rails/actions/runs/39525828126) | Complete reusable CI, strict release metadata, and packaging passed. |
| [Publication](https://github.com/yorzi/openui-rails/actions/runs/39526219367) | All 14 jobs passed, including complete CI, the owner's environment approval, OIDC publication, and release drafting. |
| Ruby/Rails matrix | Ruby 3.2, 3.3, and 3.4 with Rails 8.0 and 8.1 passed in CI. This closes the local candidate's Ruby-version gap. |
| Local candidate | Full `bin/check --runtime` on Rails 8.1.4 and 8.0.5.1: 264 core tests, 39 fixture-browser tests, 6 real-runtime tests, built-gem setup, and 14 built-gem reference tests passed on each line. |
| Public RubyGems download | Isolated install and require reported 0.9.0 with `Writer#terminated?`. A fresh host passed setup, doctor, real rendering, a CSRF-protected action, and mobile layout. The reference browser suite passed 14 tests and 144 assertions. |
| Dependencies and style | GitHub security and lint jobs passed. The local advisory check (database updated 2026-10-21) found no known vulnerabilities; RuboCop inspected 144 files without offenses. |

The 390px public-gem screenshots were inspected: the real runtime renders the
ticket, and the fallback shows ordinary HTML details with reload and restore
controls, without horizontal overflow. Browser emulation does not establish
physical-device support. No live-provider call was made for 0.9.0.

## Documentation deployment

The [release-triggered deployment](https://github.com/yorzi/openui-rails/actions/runs/39526976146)
succeeded and its log shows stable 0.9.0 plus next. HTTP checks at 01:24 and
01:25 UTC still returned the 0.5.0 install command and 404 for the new pages,
served from the CDN edge. As [RELEASING.md](RELEASING.md) prescribes, the
post-release README and roadmap commit `58b429b` triggered a
[fresh deployment](https://github.com/yorzi/openui-rails/actions/runs/39527277884),
which also built stable 0.9.0. The site served 0.9.0 from 01:27:33 UTC. These
checks cannot tell whether the first deployment would have propagated on its own.

All 18 final HTTP checks returned the expected status and content:

- Stable Getting Started (`--version 0.9.0`), Upgrading, What's New in 0.9,
  Supported API, Release History, and the archived What's New in 0.5.
- The `open-a-url` anchor in Server Actions, `LibraryVersionError` in Rendering
  Surfaces, and the snapshot re-request in Diagnostics and Recovery.
- Generated `Writer#terminated?` and `Dispatcher#call` API pages, and a 404 for
  the now-internal `RuntimeAsset` page.
- Next Supported API and Upgrading, stable and next `llms.txt`, the sitemap,
  and the home page.

## Remaining 1.0 gates

0.9.0 freezes the candidate API. These [ROADMAP.md](ROADMAP.md) conditions remain
open and belong to 0.9.x:

- A maintainer integration in a real Rails host outside `test/dummy`, using only
  public APIs, with setup friction recorded.
- One explicitly authorized, budget-bounded live-provider flow from prompt
  through rendering and an authorized action.
- The upgrade rehearsal from 0.1.0, including persisted UI and library
  mismatches, plus a verified rollback path.
- A fresh review of bundled-runtime notices, CSP requirements, and remaining
  accessibility limits.

Use 0.9.x patch releases for defects found while closing them. Rails still owns
identity, tenant scope, canonical snapshots, recovery controls, and business
integrity.
