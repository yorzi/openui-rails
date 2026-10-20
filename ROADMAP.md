# Roadmap to 1.0

Proposed on 2026-10-18 against the `0.1.0` implementation. Version `0.2.0`
was published on 2026-10-18; see [its release record](RELEASE_0_2.md).
Version `0.3.0` was published on 2026-10-19; see
[its release record](RELEASE_0_3.md). The
[local validation record](VALIDATION_0_3.md) preserves the pre-release evidence.
Version `0.4.0` is implemented as an unpublished local candidate; see
[its validation record](VALIDATION_0_4.md). Milestones after 0.4 are proposals,
not supported APIs or release dates. Work through one milestone at a time;
use patch releases for fixes and revise later scope from integration feedback.

## What 1.0 means

A developer can install the gem in a full-stack Rails app, render model-generated
UI, stream updates, execute an authorized action, and recover from delivery or
session failures using documented contracts. A multi-process app has a supported
shared idempotency store. These paths work with the pinned real browser runtime
and the built gem, not only with test doubles.

Rails continues to own records, identity, tenant scope, business transactions,
provider credentials, and snapshot persistence. The gem remains a bridge to the
official OpenUI runtime. A stable 1.x API does not require every OpenUI feature,
every provider, or a built-in chat application.

## Where 0.1.0 leaves us

The implementation already has surfaces, library fingerprints, message framing,
stream sequencing, Turbo/Action Cable transports, an authorized action endpoint,
and an optional RubyLLM adapter. See the dated [audit](AUDIT.md) for verification
and its limits.

The original 0.1 baseline identified these integration gaps. The 0.2 setup
work is released; the 0.3 reference flow exercises the built gem. The 0.4
candidate adds shared storage, with publication and remote CI still pending:

| Gap | Current evidence | Milestone |
| --- | --- | --- |
| Default setup requires manual browser-console artifact export. | `openui:install` recommends the custom-library CLI first; `openui:runtime:fetch` installs assets only. | 0.2 |
| Readiness checks have no task-level report. | `Configuration#validate!` checks files and settings but is called explicitly. | 0.2 |
| A fresh install is not tested as a complete browser workflow. | `bin/smoke-package` boots a generated host and checks mount HTML; real-runtime interaction tests use `test/dummy`. | 0.3 |
| Multi-process replay storage is left to each host. | The 0.4 candidate adds an optional SQLite-backed `ActiveRecordStore`; memory stays the default. | 0.4 |
| Failure handling requires application-specific glue. | Browser events and `on_error` exist, but there is no consolidated recovery example or server instrumentation contract. | 0.5 |
| Live generation of usable UI has limited evidence. | The audit's live probe produced a 2-byte delta, not a complete generated UI and action round trip. | 0.9 |

These are code and integration findings, not evidence of market demand.

## Release sequence

Each release depends on the preceding acceptance conditions. Version numbers
can skip unused minors; there is no need to fill 0.6 through 0.8 with features.

| Version | Focus | Result |
| --- | --- | --- |
| 0.2.0 | Two small setup features | Prepare the default library and inspect local readiness. |
| 0.3.0 | One complete reference workflow | Install, stream, act, and restore state in a fresh host. |
| 0.4.0 | Shared replay storage | Run authorized actions safely across multiple processes within the documented TTL contract. |
| 0.5.0 | Diagnostics and recovery | Explain failures and demonstrate host-owned fallback and recovery. |
| 0.9.0 and fixes | Stabilization | Freeze the candidate API and verify adoption and release paths. |
| 1.0.0 | Compatibility commitment | Publish only after all required acceptance conditions pass. |

## 0.2.0: make default setup repeatable

Keep this release to two features and the corresponding generator/doc changes.
This milestone is implemented. The acceptance conditions below remain its scope.

1. **Default-library preparation.** `openui:library:prepare` writes the prompt
   and spec exported from the exact pinned
   default runtime. Reuse the runtime's `prompt()` and `toSpec()` outputs; do not
   rebuild the library definition in Ruby. Keep custom-library builds separate.
2. **Read-only setup diagnostics.** `openui:doctor` inspects local setup.
   Report configured file validity, pinned local asset checksums, engine mount,
   and actionable setup omissions. Use a nonzero exit for required failures.
   Report checks that cannot be established statically as unverified, including
   browser registration, external assets, and application authorization quality.

Update install instructions to lead with the default chat library. Neither
task should add an allow-all authorizer, start a server, or fetch assets unless
the user explicitly invokes an operation that does so.

**Accept when:** a clean Rails host follows the documented default path without
browser-console copying, TypeScript authoring, or a paid provider. Artifacts
match the pinned runtime's actual outputs and fingerprint. Repeated preparation
preserves existing files unless overwrite is explicit. Missing or mismatched
inputs produce useful diagnostics; the report includes no credentials or prompt
contents. Tests cover real artifact extraction, repeat runs, and error exits.

**Implementation:** the maintainer exporter uses the existing Selenium/Chrome
development tools against the checksum-verified bundle. The gem ships those
exports, their provenance, and the upstream license. Applications prepare them
with Ruby alone. The real-runtime suite compares them with the actual library.

## 0.3.0: prove a complete host workflow

This milestone is implemented and published. Verification and publication
are recorded in [RELEASE_0_3.md](RELEASE_0_3.md).

Create one runnable reference host using the built gem, default library, SQLite,
importmap, and Turbo Streams. Keep it small enough to read. A support-ticket
flow should stream a response, look up a ticket with `Query()`, execute one
explicitly authorized mutation, persist the result, and show the updated surface.
Demonstrate host-owned conversation continuation without adding an agent framework.

Persist canonical response state and show scoped snapshot recovery after a
sequence gap. Restore form state and content after a page reload. Use a recorded
or deterministic stream by default; provider credentials are optional.

**Accept when:** an isolated generated host consumes the built artifact and runs
the complete browser flow with the pinned real runtime. It does not import
fixture files from this checkout. Browser tests cover reload, a lost envelope,
expired authentication, wrong-tenant access, stale actions, and duplicate
submission. A maintainer follows only the public instructions and records any
remaining manual setup. Avoid a new generator until this example proves what
needs repeating.

## 0.4.0: support shared idempotency storage

This milestone is implemented as a local candidate. The acceptance checks and
remaining release gates are recorded in [VALIDATION_0_4.md](VALIDATION_0_4.md).
Complete its release checks before starting the 0.5 diagnostics milestone.

Ship one optional Active Record store with a migration, using SQLite as the
first verified database. Keep the memory store for single-process use. Preserve
the existing `claim`/`record` interface, request digest, and ownership token.
Do not treat an ordinary cache read followed by a write as an atomic claim.

Add reusable store-conformance tests so a host can verify its own adapter.
Document result serialization, expiry cleanup, database constraints, and what
happens when a process dies after a side effect but before recording its result.

**Accept when:** independent processes competing for one live claim cannot both
own it. Completed `nil`/`false` values replay; changed requests are rejected;
expired owners cannot overwrite a replacement claim. Verify restart behavior,
tenant/actor isolation, and expiry against the real database. Demonstrate a
business uniqueness constraint in the reference host. Keep TTL overlap and crash
limits explicit; a shared store alone does not guarantee exactly-once effects.

PostgreSQL and Redis adapters are follow-up work unless a real host requires
them before 1.0. Do not claim untested database compatibility.

## 0.5.0: make failures diagnosable and recoverable

Document and stabilize the browser event payloads, action error codes, and host
recovery recipes. Add focused `ActiveSupport::Notifications` events for action
outcomes and stream termination. Include only bounded metadata such as error
code, sequence, duration, and replay status; exclude arguments, form state,
prompts, response bodies, and credentials by default.

Extend the reference host with a visible fallback, session recovery, and an
authorized snapshot request. Keep business decisions in the host. Do not
automatically retry mutations whose execution outcome is unknown.

**Accept when:** runtime load failure, library mismatch, provider failure,
oversized stream, sequence gap, stale action, and authentication expiry each
produce a documented, usable outcome. Verify that disconnect/Turbo cache
restoration does not leak listeners or requests. Keyboard users can reach
fallback and retry controls; verify accessible names and busy states. Check
diagnostic payloads for sensitive values.

## 0.9.0: freeze and qualify the candidate

Stop adding features. Resolve ambiguous public settings such as `library_name`
and `surface_id_param` before freezing them. Record the supported Ruby methods,
configuration, browser events, action/store/envelope contracts, and runtime
upgrade policy in the site. A runtime change must preserve those contracts or
include an explicit migration; never replace a pinned dependency silently.

**Accept when:**

- The exact candidate passes the configured Ruby/Rails CI matrix, dependency
  checks, real-runtime tests, built-artifact host workflow, and release checks.
- A maintainer completes a real Rails host integration outside `test/dummy`,
  using only public APIs. Record setup friction and fixes. Seek independent
  feedback, but do not invent users or require a popularity threshold.
- Run one budget-bounded, explicitly authorized live-provider flow from prompt
  through complete UI generation, browser rendering, and an authorized action.
  Record the provider/model/version and limits. Keep deterministic CI offline;
  one live success does not prove universal provider compatibility.
- Rehearse upgrading the reference host from 0.1.0, including persisted UI and
  library mismatches. Verify a documented rollback or fallback path.
- Build and inspect stable and `/next/` guides plus the API reference. Review
  the exact bundled-runtime notices, CSP requirements, keyboard flow, and
  remaining accessibility limitations.

Use 0.9.x for defects found here. Rerun the affected acceptance checks after
fixes and run the full suite against the final candidate. A failing condition
delays 1.0; it does not justify adding unrelated features.

## 1.0.0: publish the supported boundary

Release only when all required conditions above pass and there are no known
blocking defects in authorization, tenant isolation, replay handling, data
integrity, or the documented install/stream/action/recovery paths. Record any
remaining nonblocking limitations with host workarounds.

Commit to compatible public APIs throughout 1.x. Deprecate before removing APIs
in a later major version. Publish supported versions, migration notes, and the
runtime update policy with the release. Follow [RELEASING.md](RELEASING.md) for
the exact verified artifact and owner-approved publication process.

Outside the required 1.0 scope: a Ruby OpenUI parser, a component marketplace,
additional LLM adapters, API-only Rails, a generic workflow/agent engine, and
automatic business persistence. Add these only from demonstrated host needs.
