# AGENTS.md

## Development

- Use `bin/check` for local verification and `bin/check-browser` for disposable browser runs. See `DEVELOPMENT.md` for focused commands and evidence boundaries.
- Run database-backed suites sequentially. Inspect screenshots for browser changes, and turn reproducible UI regressions into assertions.
- Keep `test/dummy` as the maintained host. Verify install and generator changes against the built gem in a temporary host.
- Local checks do not establish remote CI or live-provider success. Keep artifacts synthetic, ignored, and free of credentials.

## Docs

The documentation site lives in `docs/`: Jekyll with the jekyll-vitepress-theme, in four collections (`_getting_started`, `_core_features`, `_advanced`, `_reference`). Preview it with `docs/bin/serve.sh` and build it with `docs/bin/build.sh`.

- Keep README.md short: purpose, requirements, installation, one view example, and links. Full user guides and API contracts belong in `docs/`.
- CONFIGURATION.md and UPGRADING.md are navigation stubs. Update their canonical site guides instead of duplicating instructions.
- Keep contribution, security, release procedures, dated audit evidence, and the proposed roadmap in root Markdown files. CHANGELOG.md records delivered changes, not planned features.
- A public API change is not done until its docs page changes in the same commit. Record anything that breaks existing code in `docs/_reference/upgrading.md`.
- Write in the Rails guides voice: second person, present tense, short sentences, code first, and the problem before the mechanics. No em dashes, no hype, no "simply".
- Every guide opens with its title, its description, and "After reading this guide, you will know". Explain a concept before summarizing it in a table.
- Start with the shortest working example, then options, then integration and backend-specific notes. Document a shared API once.
- Give each standalone feature a discoverable guide, and feature new ones on the release's What's New page.
- Front-matter `description` is one sentence and feeds llms.txt and link previews. Never use `&`, `<`, or `>` in it.
- Cross-link with `{% link _collection/page.md %}`, never hard-coded URLs. Keep values that change between releases in `_config.yml` and read them as `site.*` variables.
- Never edit generated pages; regenerate them.
- Public methods and classes get doc comments; mark internal code as internal.
