# 0.9.1 publication

Date: 2026-10-28. The owner authorized publication and the corresponding
documentation updates. Earlier local evidence remains unchanged in
[QUALIFICATION_1_0.md](QUALIFICATION_1_0.md).

## Published artifact

- Source: tag `v0.9.1`, commit `de83d2cff0104d7aeb4e87ef75e3e657db7459de`.
  This preserves the merged `ruby/setup-ruby` update from remote main.
- [RubyGems 0.9.1](https://rubygems.org/gems/openui-rails/versions/0.9.1),
  published at `2026-10-28T07:14:40.883Z` through GitHub OIDC.
- [GitHub Release](https://github.com/yorzi/openui-rails/releases/tag/v0.9.1),
  published at `2026-10-28T07:18:47Z`, with the gem and `SHA256SUMS` attached.
- Package size: 95,744 bytes; 80 packaged files. SHA-256:

  ```text
  ae2f679bad9e1ad6527742d1ded9493d578ec7bc434b7a9a730d06b8ec091022
  ```

Every packaged file matches its source at the tag. The publication workflow
artifact, RubyGems download and API checksum, GitHub download and asset digest,
and attached `SHA256SUMS` agree. Guest GitHub downloads were checked after the
release became public. Earlier local archive hashes identify candidate builds,
not this published artifact. The gem excludes fetched bundles, credentials,
databases, and temporary verification artifacts.

## Verification

| Gate | Result |
| --- | --- |
| [Main CI](https://github.com/yorzi/openui-rails/actions/runs/40647306614) | All 10 jobs passed for the exact tagged commit. |
| [Tag verification](https://github.com/yorzi/openui-rails/actions/runs/40647717611) | Complete reusable CI, strict metadata, and packaging passed; tag push alone did not publish. |
| [Publication](https://github.com/yorzi/openui-rails/actions/runs/40648203781) | All 14 jobs passed, including repeated CI, owner-authorized approval of the existing protected environment, OIDC upload, and release drafting. |
| Ruby/Rails matrix | Ruby 3.2, 3.3, and 3.4 with Rails 8.0 and 8.1: each 264 core tests and 793 assertions, without failures, errors, or skips. |
| Reference transactions and HTTP | Each matrix combination passed 9 tests and 52 assertions. |
| Provider-free compatibility | Each combination passed RubyLLM SSE checks (2 tests, 11 assertions) and single-request qualification checks with mocked HTTP (2 tests, 13 assertions). |
| Browser CI | 39 fixture-runtime tests and 142 assertions; 6 real-runtime tests and 34 assertions; 16 built-gem reference tests and 165 assertions. All passed without failures, errors, or skips. |
| Independent host CI | The built artifact passed 13 public-API host assertions, without dummy or Support Desk application fixtures. |
| Public RubyGems download | Temporary isolated install and require passed. A fresh host passed setup, real rendering, shared migration and replay, CSRF action, and mobile layout. The reference suite passed 16 tests and 165 assertions; the independent host passed 13 assertions. |
| Dependencies and style | GitHub security and lint passed. The refreshed local advisory check found no known dependency vulnerabilities. |
| Local release checks | Full `bin/check --runtime tmp/real-runtime --docs` and strict release metadata passed. Post-tag stable/next builds passed; 26 guides linted without errors or warnings; 2,432 guide links and anchors resolved. |

The reference checks an enforced script CSP with nonces, rejection of untrusted
inline scripts, and keyboard traversal through the generated form and action.
Its existing tenant, authentication, replay, snapshot, fallback, and Turbo
restoration checks also pass. Public-gem landing-page and 390px fallback
screenshots were inspected. Browser emulation is not physical-device or full
assistive-technology certification.

Temporary install and generated-host checks reuse cached dependencies. They
do not establish every possible dependency resolution or external adoption.
No new paid provider call was made for publication. The earlier single live
generation and 0.1.0 upgrade/rollback evidence remain in the qualification
baseline, with their original limits.

## Documentation deployment

The [release-triggered deployment](https://github.com/yorzi/openui-rails/actions/runs/40649258269)
completed successfully. Actual HTTP checks and a fresh browser still showed
stable 0.9.0 and its installation command. Next already served the new demo
guide. This does not satisfy hosted acceptance. The README, roadmap, and
publication record update in `675d9c5` triggered a
[fresh deployment](https://github.com/yorzi/openui-rails/actions/runs/40649596368).
That deployment and the update's
[complete CI](https://github.com/yorzi/openui-rails/actions/runs/40649596314)
passed. The subsequent browser reload shows `0.9.1 (stable)` and
`bundle add openui-rails --version 0.9.1`. These checks cannot establish whether
the first deployment would have propagated without the follow-up.

All 17 final canonical HTTP checks returned 200 with the expected contents:

- Stable Getting Started, Upgrading, What's New in 0.9, and Release History.
- Supported API, Diagnostics and Recovery, Production Considerations, and
  Reference Workflow, including the new demo, CSP, and preparation instructions.
- Generated Dispatcher and Stream::Bridge::Writer API methods and notifications.
- Next Getting Started, Upgrading, Reference Workflow, and Supported API.
- Stable and next `llms.txt`, plus the sitemap.

The browser also confirmed the online disposable-demo command and
`--prepare-only` instructions, and the installation page's layout was inspected.
The README, dated changelog, upgrading notes, release history, guides, and
roadmap reflect the delivered release. Raw optional local evidence remains in
ignored `drafts/release-0.9.1/`; screenshots remain under `tmp/browser/`.
Task-owned temporary services and browser tabs were stopped after verification.

## Supported boundary and next step

The demo command belongs to the development checkout. The opt-in reference
uses recorded generation and synthetic accounts; it is not production login
code. Its script policy still permits inline styles required by runtime 0.2.1.
Public gem APIs, runtime pins, migrations, and declared dependencies are unchanged.

Version 1.0 still needs removal of the deprecated no-op settings, verification of
the exact final 1.0 candidate, and its own authorized public release acceptance.
See [ROADMAP.md](ROADMAP.md). Keep earlier candidate and release records as
historical evidence; documentation follow-ups do not move the tag or change
the published gem.
