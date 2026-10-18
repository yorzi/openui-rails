# Releasing `openui-rails`

`openui-rails` is an **unofficial** integration. Do not publish a release, or
claim affiliation, until the legal and naming checks in the spec are cleared by
a human owner. The workflow in this document prepares and publishes a release;
it does not decide that one is allowed.

## Preconditions

- [ ] `main` is green on the full CI matrix (lint, test, build, system).
- [ ] Gem name availability and the "OpenUI" naming / trademark question are
      confirmed by the owner (see `THIRD_PARTY_NOTICES.md`).
- [ ] `THIRD_PARTY_NOTICES.md` reflects the exact pinned runtime/CLI versions.
- [ ] `CHANGELOG.md` has a `## [x.y.z]` section for the release, with the
      version moved out of `[Unreleased]`.
- [ ] `lib/openui/rails/version.rb` matches that version.
- [ ] A human owner has read the release notes.

## Steps

1. Move the `[Unreleased]` entries under a new `## [x.y.z] - YYYY-MM-DD`
   heading in `CHANGELOG.md` and add the compare link.
2. Bump `lib/openui/rails/version.rb` to `x.y.z`.
3. Commit both: `Prepare vx.y.z`.
4. Tag and push:

   ```bash
   git tag vx.y.z
   git push origin main --tags
   ```

5. The [`release`](.github/workflows/release.yml) workflow runs on the tag. It
   re-checks that the tag matches `OpenUI::Rails::VERSION`, builds the gem,
   publishes it to RubyGems using the `RUBYGEMS_API_KEY` secret, and drafts a
   GitHub release. The job targets the `release` GitHub environment, so add a
   required reviewer there to make publication a deliberate, approved step.
6. Verify the version on RubyGems and the generated sources on GitHub.

## Manual fallback

If the workflow is unavailable:

```bash
bundle exec bin/rails test
bundle exec bin/rails test:system
bundle exec rubocop
gem build openui-rails.gemspec
gem push openui-rails-x.y.z.gem   # requires a RubyGems API key
```

## Rollback

- Prefer a fast follow-up patch release for a fix.
- To remove a broken version from RubyGems: `gem yank openui-rails -v x.y.z`.
- Document any breaking change and its migration in `CHANGELOG.md`; `0.x`
  releases permit documented breaking changes.
