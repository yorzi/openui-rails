# 0.3.0 publication

Date: 2026-10-19. The owner authorized pushing and publishing this release.

## Published artifact

- Source: tag `v0.3.0`, commit `b111fba81d50c6934bf603922b305f88258d2d4d`.
- [RubyGems 0.3.0](https://rubygems.org/gems/openui-rails/versions/0.3.0),
  published at `2026-10-19T11:17:52.083Z` through GitHub OIDC.
- [GitHub Release](https://github.com/yorzi/openui-rails/releases/tag/v0.3.0),
  published at `2026-10-19T11:19:08Z`, with the gem and `SHA256SUMS` attached.
- Package size: 86,528 bytes; 75 packaged files. SHA-256:

  ```text
  3ffc037d18b92cdcf250a72fc80cd1ed5b06eba50c2a1cae2f6ea3ed646d0340
  ```

The RubyGems download matches the verified publication workflow artifact,
RubyGems API checksum, GitHub asset digest, and attached `SHA256SUMS`.
The package excludes the fetched runtime bundle, databases, and test artifacts.

## Verification

| Gate | Result |
| --- | --- |
| [Main CI](https://github.com/yorzi/openui-rails/actions/runs/39242537182) | All jobs passed for the tagged commit. |
| [Tag verification](https://github.com/yorzi/openui-rails/actions/runs/39242876368) | Complete reusable CI, release metadata, and packaging passed. |
| [Publication](https://github.com/yorzi/openui-rails/actions/runs/39243177637) | Complete CI passed again; protected environment approved under the owner's authorization; OIDC publication and release drafting passed. |
| Ruby/Rails matrix | Ruby 3.2, 3.3, and 3.4 with Rails 8.0 and 8.1: each 232 core tests and 619 assertions, with no failures, errors, or skips. |
| Reference transactions and HTTP | Each matrix combination passed 9 tests and 52 assertions, including real CSRF protection. |
| RubyLLM 2.1.1 | Real SSE parser with mocked HTTP: 1 test and 7 assertions on each matrix combination. |
| Browser CI | 33 fixture-runtime tests and 109 assertions; 6 real-runtime tests and 34 assertions; 8 built-gem reference tests and 81 assertions. All passed without failures, errors, or skips. |
| Built-gem setup CI | Fresh host install, setup tasks, real rendering, CSRF-protected action, and mobile layout passed. |
| RubyGems download | A fresh isolated host consumed the publicly downloaded artifact; 8 reference browser tests and 81 assertions passed without failures, errors, or skips. |
| Dependencies and style | GitHub security and lint jobs passed. |
| Local release verification | Full `bin/check --runtime tmp/real-runtime --docs` passed; post-tag stable 0.3 and next builds passed; 20 guides linted without errors or warnings; 1,604 guide links and anchors passed. |

The reference uses recorded generation. No live-provider call was made for
0.3.0. Package checks use disposable Rails hosts and cached dependencies;
they do not establish external adoption or every possible dependency resolution.
The gem's default replay store remains process-local. Shared storage is proposed
for 0.4; the reference's database receipt protects one domain operation.
See [the local candidate record](VALIDATION_0_3.md) for earlier evidence and its
distinct pre-release artifact checksum. Strict conversation action schemas
must allow the runtime metadata they consume; see the upgrading guide.

## Documentation deployment

The [release-triggered deployment](https://github.com/yorzi/openui-rails/actions/runs/39243772090)
completed successfully. An initial browser check still showed stable 0.2.0.
The publication record and README update in commit `25574c0` triggered a
[fresh successful deployment](https://github.com/yorzi/openui-rails/actions/runs/39243876815).
Subsequent HTTP checks and a real-browser reload confirmed the stable version
selector and installation command both name 0.3.0. The stable navigation exposes
What's New in 0.3 and Reference Workflow. A screenshot remains in ignored
`tmp/evidence/0.3.0-hosted-docs.png`.

All 12 hosted checks returned HTTP 200 with the expected contents:

- Stable Getting Started, Upgrading, What's New in 0.3, and Release History.
- Reference Workflow and Setup Diagnostics.
- The generated Surface API reference, including restored stream metadata.
- Next Getting Started and Upgrading, following `main`.
- Stable and next `llms.txt`, including the reference workflow links.
- The sitemap, including the new release and workflow guides.

The actual RubyGems download also passed the isolated reference-host browser
suite described above. Temporary test servers and browser sessions were stopped.
The release tag and published artifact remain unchanged by these documentation
records.
