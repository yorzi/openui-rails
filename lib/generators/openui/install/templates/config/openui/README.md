# OpenUI library artifacts

This directory holds the **prompt** and **spec** generated from the same,
version-pinned component-library revision. Both must come from one revision so
the model prompt and the browser component library cannot drift.

The default browser bundle contains `openuiChatLibrary` only. For that bundle,
save the exact outputs of `window.__OpenUI.openuiChatLibrary.prompt()` and
`.toSpec()` as the prompt text and JSON spec. A custom library needs a matching
host-built runtime; the CLI does not change the default browser bundle.

For a custom library, use the pinned CLI (never `@latest`):

```bash
npx --yes @openuidev/cli@0.6.0 generate ./src/library.ts --out config/openui/library.prompt.txt --no-telemetry
```

The command writes `config/openui/library.prompt.txt` and
`config/openui/library.prompt.txt.spec.json`. Rename the spec to
`library.spec.json` (or point `library_spec_path` at the generated name) and
commit both files. `OpenUI::Rails` fingerprints the spec; a mismatched
fingerprint is a visible failure rather than a silent re-render.

Set `DO_NOT_TRACK=1` in CI as well as `--no-telemetry`.
