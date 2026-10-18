# Releasing openui-rails

No release has been published. Do not publish until the owner clears the gates
below. This is an unofficial integration, not a Thesys product.

## Publication gates

- [ ] Review [AUDIT.md](AUDIT.md) and the complete CI result for the release commit.
- [ ] Confirm the RubyGems name, branding, and upstream notice obligations.
- [ ] Review the exact browser bundle's transitive licenses. See [notices](THIRD_PARTY_NOTICES.md).
- [ ] Complete one explicitly authorized, budget-capped live-provider smoke run.
- [ ] Review release notes and destructive-action approval policies.
- [ ] Confirm the repository visibility and public support/security contact plan.
- [ ] Configure the GitHub `release` environment with required reviewers.
- [ ] Store a least-privilege `RUBYGEMS_API_KEY` in that environment.

An environment name in a workflow does not configure reviewers. The audit found
no repository environments or secrets on 2026-10-18. No credentials were added.

## Prepare the candidate

1. Set the version in `lib/openui/rails/version.rb`.
2. Add a dated `## [x.y.z] - YYYY-MM-DD` changelog section.
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
pushes it to `https://rubygems.org`, and creates a **draft** GitHub release.

Verify the RubyGems version. Review the GitHub draft before making it public.
The current `0.1.0` changelog is still unreleased, so `bin/check-release`
intentionally refuses to approve that tag.

## Recovery

Prefer a patch release for a defect. If a published version is unsafe, the owner
can yank it:

```bash
gem yank openui-rails -v x.y.z
```

Record the reason and migration steps. A yank does not undo installations or
business side effects. Hosts must keep database-level safeguards for irreversible
actions and must review [UPGRADING.md](UPGRADING.md) before deployment.
