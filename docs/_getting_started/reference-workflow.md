---
layout: default
title: Reference Workflow
nav_order: 6
description: Run a provider-free support-ticket workflow with persistent state and scoped recovery from a built gem.
---

# {{ page.title }}

{{ page.description }}
{: .fs-6 .fw-300 }

After reading this guide, you will know:

* How to run the reference host from the built gem.
* How Rails owns ticket actions, conversation state, and recovery.
* Which failure cases the browser checks cover and which limits remain.

## Run the complete check

From the repository, install the development dependencies and fetch the exact
pinned runtime. The fetch needs npm and network access; subsequent checks use
local assets and synthetic data. Chrome is required.

```sh
bundle install
bundle exec rake "app:openui:runtime:fetch[$PWD/tmp/real-runtime]"
mkdir -p tmp/package
bundle exec gem build openui-rails.gemspec --output tmp/package/openui-rails-{{ site.version }}.gem
bin/check-reference --gem tmp/package/openui-rails-{{ site.version }}.gem --runtime tmp/real-runtime
```

The command generates a disposable Rails host with SQLite, importmap, Stimulus,
and Turbo. Its gem and reference application come from the extracted artifact.
Its prompt and spec come from `openui:library:prepare`. It uses cached development
dependencies with `bundle install --local`; it does not prove a clean online
installation. It imports no application fixtures from `test/dummy`.

Use `bin/check-reference` without `--gem` for host transaction tests against the
same reference code loaded by `test/dummy`. Add `--runtime tmp/real-runtime` to
run the real browser there too. Database-backed runs use separate temporary
databases and run sequentially.

## Inspect a retained host

Choose a new directory whose parent exists:

```sh
bin/check-reference --gem tmp/package/openui-rails-{{ site.version }}.gem \
  --runtime tmp/real-runtime --host tmp/support-desk
cd tmp/support-desk
RAILS_ENV=test DATABASE_URL="sqlite3:$PWD/storage/reference-test.sqlite3" \
  bin/rails server --binding 127.0.0.1 --port 3000
```

Open `http://127.0.0.1:3000/support`. The check prints the retained directory and
leaves no server running. A retained host resets only its newly created
synthetic reference records after the checks, so your review starts with open
tickets. The last command starts your review session; stop it
with Ctrl-C when you finish. The directory contains synthetic records and
screenshots remain under the source repository's ignored `tmp/browser/` path.
Sign in as Alice for an agent in the north tenant, Bob for the south tenant,
or Reader for a read-only user. Accounts are deliberately synthetic and the
reference routes accept loopback clients only. Replace this session code with
your application's authentication before adapting the example. The reference
explicitly enables CSRF protection, including when the local server uses the
test environment. Its browser driver checks this setting instead of enabling
it on behalf of the application.

## Follow the ticket workflow

Start with Alice. The response arrives as newline-delimited Turbo Stream
append elements. The host browser controller feeds each element to Turbo;
`openui-envelope` delivers its ordered envelope to the surface. This example
uses an authenticated HTTP response, not a shared WebSocket subscription.
It does not require Action Cable, Redis, background jobs, or a paid provider.

The deterministic source substitutes for model generation. Rails stores the
complete canonical output and its watermark before delivering frames, so a
lost connection does not erase the response. A real provider integration must
persist output and watermarks consistently as generation progresses.

The rendered `Query("ticket_lookup", ...)` reads the conversation's scoped
ticket. Enter a private note and wait for **Draft saved** before reloading.
`openui:state` sends a bounded form-state update to the host; the next page
restores it through `initial_state:`. This is explicit server persistence,
not browser storage or an unload-delivery guarantee.

**Continue conversation** emits `@ToAssistant`. The bridge forwards its message
and form metadata to `continue_conversation`. The host validates them, appends
a user turn, increments the action revision, and starts a new message identity.
The next deterministic response shows the turn count. No agent framework runs.

**Close ticket** runs a `Mutation()`. The host authorizes the actor and scoped
conversation, rechecks its revision inside the database transaction, closes
the ticket, and writes a receipt protected by a unique database index. The
next response queries and shows the persisted closed status.

## Recover and reject unsafe requests

A missing envelope raises `openui:snapshot-required`. The host fetches the
canonical snapshot through an authenticated, actor-and-tenant-scoped endpoint.
Its sequence is the last persisted envelope, including completion. A reload
restores `next_sequence` and `completed`, fencing late frames from that message.

The browser suite verifies these paths:

| Case | Expected outcome |
| --- | --- |
| Saved draft and page reload | Form value, response, and stream watermark survive. |
| Dropped Turbo Stream element | One scoped snapshot restores the canonical response. |
| Expired identity | Snapshot and action requests are denied without modifying a ticket. |
| Wrong tenant | Show, stream, snapshot, state, and action requests disclose no other ticket. |
| Reader account | Query succeeds; mutation is denied. |
| Duplicate and stale action | One receipt persists; repeats or stale revisions do not repeat the effect. |
| Missing CSRF token or invalid state | Request fails before a business mutation. |
| Keyboard and 390px layout | The action works from the keyboard and the page has no horizontal overflow. |

Revision checks run before replay lookup. A duplicate from an older revision
can return `409 stale_surface` instead of replaying a successful response. Reload
the canonical state; do not assume every duplicate returns HTTP 200.

The gem defaults to its process-local memory store. This reference opts into
`ActiveRecordStore` and runs the generated `openui:idempotency` migration alongside
its own migrations. Stored action results survive worker restarts. Its database
receipt still protects the close operation after claim expiry or a crash;
shared replay storage does not guarantee exactly-once external effects. See
[Shared Idempotency Storage]({% link _advanced/shared-idempotency.md %}).

## Adapt the source

The gem includes `examples/support_desk`. `boot.rb` opts the reference code into
a host, and `install.rb` wires that explicit reference into a generated app.
It is not loaded by `require "openui/rails"` and is not a general-purpose app
generator. Read its models for persistence, initializer for scoped actions,
controllers for request boundaries, and `support_desk.js` for streaming and
state events. Keep these responsibilities in your application.

## Next Steps

* [Streaming]({% link _core_features/streaming.md %}) - inspect sequence and snapshot contracts.
* [Server Actions]({% link _core_features/actions.md %}) - configure host authorization and validation.
* [Upgrading]({% link _reference/upgrading.md %}) - allow the conversation metadata you consume.
