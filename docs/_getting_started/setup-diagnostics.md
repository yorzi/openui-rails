---
layout: default
title: Setup Diagnostics
nav_order: 4
description: Check local library files, runtime checksums, and the engine route without executing actions or fetching assets.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to find missing setup steps.
* Which checks require a browser or application review.

## Inspect local setup

Use the diagnostic task after installing the engine and preparing its files:

```sh
bin/rails openui:doctor
```

The task loads your Rails environment, then reads the configured library files,
checks numeric limits, inspects the engine mount, and verifies default local
runtime assets against the gem's checksums. It also checks that the prompt and
spec match the default library when you use the default runtime.

It does not write setup files, start a server, fetch assets, invoke host
authorization or surface callbacks, or call a provider. Your application's normal
boot initializers still run. Reports omit file contents and raw exception text.
Route constraints are not executed. A dynamic mount is reported as unverified;
test its action URL and access rules through an actual host request.

## Interpret the report

Each check has a status and a next action. A successful command means required
local checks passed; it does not certify production readiness.

| Status | Meaning |
| --- | --- |
| `PASS` | The local check succeeded. |
| `FAIL` | Fix a required setup problem. The command exits with status 1. |
| `UNVERIFIED` | Review this responsibility in your host or browser. This alone does not change the exit status. |

For missing default library files, run `openui:library:prepare`. For missing or
mismatched pinned assets, run `openui:runtime:fetch`. A route failure means your
engine mount and `actions_endpoint` do not agree. Preserve custom files before
replacing them.

Custom and external assets are reported as unverified when their URL and
integrity settings exist. Doctor does not contact those URLs. Verify their
contents and actual browser library separately.

## Complete host verification

Use a browser to verify Stimulus registration, stylesheet loading, rendering,
and event handling. Review actor resolution, tenant-scoped surface access,
global or per-action authorization, shared idempotency storage, stream
subscriptions, snapshot recovery, and fallback UI. Doctor never executes an
authorizer to infer whether its policy is correct. Actions without an authorizer
remain denied.

## Next Steps

* [Library and Prompt Contract]({% link _core_features/library-contract.md %}) - prepare default or custom library files.
* [Runtime Assets]({% link _core_features/runtime-assets.md %}) - fetch and register the browser assets.
* [Production Considerations]({% link _advanced/production.md %}) - review host responsibilities.
