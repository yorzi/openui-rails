# 0.2.0 publication

Date: 2026-10-18. The owner authorized pushing and publishing this release.

## Published artifact

- Source: tag `v0.2.0`, commit `be92f9ade7a54bbdae592bad8d7895eae5b69525`.
- [RubyGems 0.2.0](https://rubygems.org/gems/openui-rails/versions/0.2.0),
  published at `2026-10-18T13:39:04.401Z` through GitHub OIDC.
- [GitHub Release](https://github.com/yorzi/openui-rails/releases/tag/v0.2.0),
  published at `2026-10-18T13:40:26Z`, with the gem and `SHA256SUMS` attached.
- Package size: 77,824 bytes. SHA-256:

  ```text
  e30ee6e2bbf200d21e8cfbabf68e8c66ae4e97ed58f7c74fdd39ae9072313ca3
  ```

The RubyGems download matches the verified workflow artifact, RubyGems API
checksum, GitHub asset digest, and attached `SHA256SUMS`.

## Verification

| Gate | Result |
| --- | --- |
| [Main CI](https://github.com/yorzi/openui-rails/actions/runs/39131815414) | All jobs passed for the tagged commit. |
| [Tag verification](https://github.com/yorzi/openui-rails/actions/runs/39132017900) | Complete reusable CI, release metadata, and packaging passed. |
| [Publication](https://github.com/yorzi/openui-rails/actions/runs/39132225795) | Complete CI passed again; protected environment approved under the owner's authorization; OIDC publication and release drafting passed. |
| Ruby/Rails matrix | Ruby 3.2, 3.3, and 3.4 with Rails 8.0 and 8.1: each 227 tests and 600 assertions, with no failures, errors, or skips. |
| RubyLLM 2.1.1 | Real SSE parser with mocked HTTP: 1 test and 7 assertions on each matrix combination. |
| Browser CI | 32 tests and 104 assertions with the fixture runtime; 6 tests and 33 assertions with the real pinned 0.2.1 runtime; no failures, errors, or skips. |
| Built-gem CI | Fresh host install, setup tasks, real browser rendering, CSRF-protected action, and mobile layout passed. |
| RubyGems download | Repeated the fresh-host and real-browser package checks locally using the downloaded published gem; all passed. |
| Dependencies and style | GitHub security and lint jobs passed. |
| Local documentation | Stable 0.2.0 and next built; 18 guides linted without errors or warnings; 1,370 internal guide links and anchors passed. |

Package smoke checks use a disposable Rails host and cached developer or CI
dependencies. They do not establish external adoption or compatibility with
every dependency resolution. No live-provider call was made for 0.2.0.
See [local candidate validation](VALIDATION_0_2.md) for earlier evidence and
its distinct pre-release artifact checksum.

## Documentation deployment

The [release-triggered deployment](https://github.com/yorzi/openui-rails/actions/runs/39132577711)
built 0.2.0 and reported success, but hosted verification still returned the
previous stable 0.1.0 page. The follow-up commit `1247236` triggered a
[fresh successful deployment](https://github.com/yorzi/openui-rails/actions/runs/39132881709).
Subsequent hosted checks confirmed the stable version selector and installation
command both name 0.2.0. The page was also checked in a real browser.

All 12 hosted checks returned HTTP 200 with the expected contents:

- Stable Getting Started, Upgrading, What's New in 0.2, and Release History.
- Setup Diagnostics and Library and Prompt Contract.
- The generated API reference.
- Next Getting Started and Upgrading, both following `main`.
- Stable and next `llms.txt`, with the matching channel names and guide links.
- The sitemap, including the new release guide.

The [follow-up CI](https://github.com/yorzi/openui-rails/actions/runs/39132881692)
also passed. All temporary test servers and browser sessions were stopped.
The release tag and RubyGems artifact remain unchanged by these documentation
records.
