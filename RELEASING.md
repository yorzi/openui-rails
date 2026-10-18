# Releasing openui-rails

The owner authorized the initial `0.1.0` release on 2026-10-18. This is an
unofficial integration, not a Thesys product. Publish only a tag whose complete
CI suite and release metadata checks pass.

## Publishing configuration

The public repository is `yorzi/openui-rails`. Its GitHub `release` environment
requires approval by `yorzi`, accepts the `main` branch, and disallows
administrator bypass. Self-review is available for the single maintainer.
RubyGems trusts workflow `release.yml` and environment `release` through GitHub
OIDC. No long-lived RubyGems API key is stored in GitHub.

The initial pending publisher was registered and successfully used for `0.1.0`
on 2026-10-18. Future releases use the gem's Trusted Publisher. Update RubyGems
trust before changing the repository, workflow filename, or environment.

The documentation uses GitHub Pages with the GitHub Actions source. Its
`github-pages` environment permits branch `main` and tags matching `v*`.
Both rules are needed: a published release triggers the docs workflow with
the release tag, even though the workflow checks out the default branch to
build the stable and next documentation channels.

Before each release, review [AUDIT.md](AUDIT.md), the dated changelog section,
and the complete CI result for the exact commit. Preserve third-party notices.
The gem excludes the upstream browser bundle; host applications that
redistribute the fetched bundle must review that exact bundle's complete
transitive license inventory. See [notices](THIRD_PARTY_NOTICES.md).

The live smoke completed on 2026-10-18 through OpenRouter with RubyLLM 2.1.1
and `openai/gpt-4.1-mini`. It used a synthetic prompt, `:complete` streaming,
and a 16-token output cap. See [AUDIT.md](AUDIT.md) for the result and limits.

## Prepare the candidate

1. Set the version in `lib/openui/rails/version.rb`.
2. Add a dated `## [x.y.z] - YYYY-MM-DD` changelog section.
   Set the same version and `released: true` in `docs/_config.yml`, update
   What's New, release history, and upgrading instructions, then run the docs
   check and build.
3. Run the full verification suite described in [CONTRIBUTING.md](CONTRIBUTING.md).
4. Run the release metadata check:

   ```bash
   RELEASE_TAG=vx.y.z ruby bin/check-release
   ```

5. Commit the version and notes.
6. Create the release tag:

   ```bash
   git tag -a vx.y.z -m "Release vx.y.z"
   ```

7. Push that tag:

   ```bash
   git push origin vx.y.z
   ```

The tag workflow runs the full reusable CI suite. It then checks release
metadata and uploads the built gem. **A tag push does not publish to RubyGems.**

## Publish after owner approval

After all gates pass, start the Release workflow manually:

```bash
gh workflow run release.yml --ref main -f tag=vx.y.z -F publish=true
```

The workflow tests the selected tag again. The publish job waits for the
configured environment reviewers. It downloads that run's verified artifact,
obtains a short-lived, gem-scoped RubyGems credential through OIDC, and pushes
the artifact to `https://rubygems.org`. A separate job with GitHub release
write permission then creates a **draft** GitHub release.

The draft includes the verified gem, its SHA-256 checksum, and the dated
changelog section. Verify the RubyGems version and review that draft before
making it public.
`CHANGELOG.md` now contains the dated `0.1.0` notes, and
`RELEASE_TAG=v0.1.0 ruby bin/check-release` accepts the release metadata.

## Recovery

Prefer a patch release for a defect. If a published version is unsafe, the owner
can yank it:

```bash
gem yank openui-rails -v x.y.z
```

Record the reason and migration steps. A yank does not undo installations or
business side effects. Hosts must keep database-level safeguards for irreversible
actions and must review [UPGRADING.md](UPGRADING.md) before deployment.
