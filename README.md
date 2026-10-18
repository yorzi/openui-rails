# openui-rails

[![CI](https://github.com/yorzi/openui-rails/actions/workflows/ci.yml/badge.svg)](https://github.com/yorzi/openui-rails/actions/workflows/ci.yml)

[Documentation](https://openui-rails.wangyaodi.com/)

Render model-generated, streaming, interactive **OpenUI Lang** UI inside an
existing Rails application — without migrating the whole frontend to a
React/Next.js SPA and without hand-writing the stream, state and action glue
for every screen.

> **Unofficial integration.** `openui-rails` is not affiliated with, endorsed
> by, or maintained by Thesys. It reuses the official, version-pinned OpenUI
> JavaScript runtime (loaded in the browser) and keeps Rails authoritative for
> authentication, authorization and persistence. It is **not** a Ruby
> reimplementation of OpenUI Lang — there is no Ruby parser or renderer in this
> Gem.

## What it does

- **Rails view helper + Stimulus bridge** that mounts the official OpenUI
  renderer against a server-owned surface record.
- **Versioned library/prompt contract** so the model prompt and the browser
  component library are generated from the *same* library revision, with a
  SHA-256 fingerprint persisted alongside the response.
- **Ordered streaming** envelopes with snapshot recovery when chunks arrive out
  of order or a client reconnects. Transport-agnostic: broadcast over Turbo
  Streams or Action Cable.
- **A single, authorized action loop**: component `onAction` and browser
  `toolProvider` `Query()`/`Mutation()` calls both route through one allowlisted
  endpoint with CSRF, tenancy, staleness and idempotency controls. It fails
  closed.
- **Optional RubyLLM adapter** that owns RubyLLM-specific event normalization.

RubyLLM is an optional integration, never a core dependency. Rails remains the
source of truth for users, tenants and business objects.

## Requirements

| Component | Supported |
| --- | --- |
| Ruby | `>= 3.2` |
| Rails | `>= 8.0` (`< 9.0`) |
| OpenUI browser runtime | pinned JS runtime, `@openuidev/browser-bundle` **0.2.1** |
| OpenUI CLI (prompt generation) | pinned `@openuidev/cli` **0.6.0** |
| RubyLLM | optional; **2.1.1** verified through its real OpenAI chat-completions SSE parser with mocked HTTP |

Unknown provider/version combinations are *unsupported*, not implicitly
compatible. The JavaScript runtime is always referenced by an exact version;
there is no `@latest` or floating CDN range.

> **Rails 8.0 note.** On the Rails 8.0.x line, use `json < 3`. Rails 8.0's
> ActiveSupport and integration-test helpers pass a `quirks_mode:` keyword to
> `JSON.generate` that `json` 3.1 removed; Rails 8.1 no longer does. CI covers
> both lines (`RAILS_VERSION` in the `Gemfile` pins the matrix).

## Installation

```ruby
# Gemfile
gem "openui-rails", "~> 0.1.0"
```

```bash
bundle install
bin/rails generate openui:install
```

The generator writes `config/initializers/openui.rb`, creates `config/openui/`
and mounts the engine:

```ruby
# config/routes.rb
mount OpenUI::Rails::Engine => "/openui-rails"
```

It intentionally does **not** download the runtime or generate the library
prompt — those are explicit, reproducible steps (below).

## Quickstart

### 1. Configure

```ruby
# config/initializers/openui.rb
OpenUI::Rails.configure do |config|
  config.transport = :turbo          # :turbo, :action_cable or :none
  config.library_spec_path = Rails.root.join("config/openui/library.spec.json")
  config.prompt_path       = Rails.root.join("config/openui/library.prompt.txt")
  config.runtime_assets    = :self_hosted   # :self_hosted or :external

  # Authz is required and fails closed: with no authorizer an action is denied.
  config.authorize_action = ->(invocation) { invocation.actor.present? }

  # Resolve a surface id to a record scoped to the actor/tenant. Returning nil
  # is treated as an unknown/inaccessible surface and denies the action.
  config.surface_resolver = ->(surface_id, actor:, **) {
    actor&.surfaces&.find_by(id: surface_id)
  }

   # The engine inherits your ApplicationController, including authentication
   # filters. It reads current_user by default; configure this for other auth.
  config.actor_resolver = ->(controller) { controller.current_user }
end
```

### 2. Generate the library prompt and spec

The default browser bundle contains **only `openuiChatLibrary`**. Its prompt
and spec must describe that exact library, not an unrelated custom library.
The loaded bundle exposes `window.__OpenUI.openuiChatLibrary.prompt()` and
`.toSpec()`. Save those outputs as the configured prompt text and JSON spec.
The compatibility suite verifies this exact workflow against the pinned bundle.

For a host-built custom library, use the pinned CLI and a matching host-built
runtime that exposes the same `window.__OpenUI` contract. The CLI alone does
not add components to the default browser bundle:

```bash
npx --yes @openuidev/cli@0.6.0 generate ./src/library.ts \
  --out config/openui/library.prompt.txt --no-telemetry
# rename the emitted library.prompt.txt.spec.json to library.spec.json
# (or point library_spec_path at the generated name) and commit both.
```

Set `DO_NOT_TRACK=1` in CI as well as `--no-telemetry`.

### 3. Self-host the pinned runtime

```bash
bin/rails openui:runtime:fetch   # vendors the bundle into public/openui (needs npm)
```

The task checks the archive and exact JS/CSS/license files against committed
checksums. It disables npm lifecycle scripts and never extracts archive paths
to disk. The default runtime and stylesheet use pinned SRI hashes.

Include the stylesheet once in your layout's `<head>`:

```erb
<%= openui_stylesheet_tag %>
```

For external assets, configure both `runtime_url` and `runtime_stylesheet_url`
with exact-version URLs. Supply their integrity hashes too.

### 4. Register the Stimulus controllers

The engine adds its `app/javascript` directory to the asset paths, so the
controllers are available to the asset pipeline. For importmap, add the pins:

```ruby
# config/importmap.rb
pin_all_from OpenUI::Rails::Engine.root.join("app/javascript/openui"), under: "openui"
```

```js
// app/javascript/controllers/index.js
import { application } from "controllers/application"
import OpenUIController from "openui/rails/openui_controller"
import OpenUIEnvelopeController from "openui/rails/openui_envelope_controller"

application.register("openui", OpenUIController)
application.register("openui-envelope", OpenUIEnvelopeController)
```

The `openui` controller mounts the renderer; `openui-envelope` is only needed
for the Turbo Streams transport (below).

### 5. Render a surface

```erb
<%# @surface is any object exposing #id (and optionally #version,
    #library_version, #response, #context, #message_id) %>
<%= openui_surface(surface: @surface, stream: true) %>
```

Pass `label: "Order details"` to expose the mount as a named `region` landmark.
A streaming surface carries `aria-busy="true"` until it completes, so assistive
technology waits for the region to settle instead of announcing each delta.

### 6. Register actions

```ruby
# config/initializers/openui.rb (or an initializer of your own)
OpenUI::Rails.actions.register "orders.refresh",
  description: "Re-fetch an order",
  schema: { "orderId" => String },
  authorize: ->(invocation) { OrderPolicy.new(invocation.actor, invocation.args["orderId"]).refresh? },
  handler: ->(invocation) { OrderSerializer.new(Order.find(invocation.args["orderId"])).as_json }
```

## Rendering surfaces

```ruby
openui_surface(surface = nil, stream: false, dom_id: nil, initial_state: nil, label: nil, **options)
```

`Surface.coerce` accepts a `Surface`, a plain `Hash`, or a host record. It
emits a flat `data-openui-*` mount element; the Stimulus controller reads it and
never receives a credential or a server secret. Recognised record methods:
`id`, `version`, `library_version`, `response`, `context`, `message_id`.

When a manifest is configured, the helper rejects an incompatible persisted
`library_version`. Before mounting, the browser hashes the runtime library's
`toSpec()` output and compares it with that manifest. A mismatch emits
`openui:error` with `library_version_mismatch` and does not mount the renderer.
Without a configured manifest, no library identity check is possible.

## Streaming

The stream bridge normalizes model output into ordered envelopes and coalesces
small chunks up to `pending_byte_limit` (default 32 KiB), enforcing
`stream_byte_limit` (default 1 MiB).

Envelope types: `openui.delta`, `openui.snapshot`, `openui.completed`,
`openui.error`. Every envelope carries `message_id`, `sequence` (from `0`) and
an optional `library_version`.

```ruby
bridge = OpenUI::Rails::Stream::Bridge.new(
  message_id: surface.id, library_version: config.library_fingerprint
)

# Pull source (an Enumerable of chunks):
bridge.envelopes(chunks).each { |envelope| broadcast(envelope) }

# Push source (a streaming provider callback):
writer = bridge.writer
writer.push(chunk).each { |envelope| broadcast(envelope) }
writer.finish.each { |envelope| broadcast(envelope) }
```

The browser controller applies envelopes in order, ignores duplicates, and
requests a canonical snapshot (`openui:snapshot-required` event) when it detects
a sequence gap. Deltas pause until a current snapshot arrives. Stale snapshots,
duplicate terminal frames, malformed frames, and post-completion deltas cannot
rewind or extend a completed response. The browser also enforces the byte limit.

The controller **receives** `openui:envelope` and emits `openui:action`,
`openui:state`, `openui:error`, and `openui:snapshot-required`. Your host must
fetch and dispatch the authoritative snapshot on a gap or reconnect. The gem
does not provide a persistence layer or snapshot HTTP endpoint.

### Transports

`Stream::Broadcaster` binds the bridge to a transport and broadcasts each
envelope as it is produced. Delivery is best effort — neither Action Cable nor
Turbo Streams guarantee order — which is exactly why the client applies
sequence numbers and recovers from a snapshot on a gap.

```ruby
transport = OpenUI::Rails::Stream::Transports.build(:action_cable, stream_name: "openui:surface:#{surface.id}")
# or: Transports.build(:turbo, stream: surface, target: "openui-surface-#{surface.id}")
# or: Transports.build(:memory)   # tests/examples

broadcaster = OpenUI::Rails::Stream::Broadcaster.new(
  transport: transport, message_id: surface.id, library_version: config.library_fingerprint
)
chat.complete { |chunk| broadcaster.push(chunk.content) }
broadcaster.finish
```

- **Action Cable** (`:action_cable`) broadcasts the envelope hash. Subscribe in
  the browser and re-emit it as an event; authorization for the subscription
  stays in your channel:

  ```js
  import { createConsumer } from "@rails/actioncable"
  const consumer = createConsumer()
  consumer.subscriptions.create(
    { channel: "YourStreamChannel", stream: "openui:surface:42" },
    { received: (data) =>
        document.dispatchEvent(new CustomEvent("openui:envelope", { bubbles: true, detail: data })) }
  )
  ```

- **Turbo Streams** (`:turbo`) appends an `openui-envelope` element to a target
  already in the DOM. The `openui-envelope` controller re-emits the envelope as
  a bubbling `openui:envelope` event and removes itself — no inline script, no
  CSP relaxation. This transport requires `turbo-rails` in the host; it is
  looked up lazily and never a hard dependency of this Gem.

  Subscribe with `<%= turbo_stream_from stream %>` and provide a dedicated
  inbox, such as `<div id="openui-inbox" hidden></div>`. Pass that inbox's ID
  as `target:`. Keep the inbox outside the React-owned subtree. Restrict stream
  subscription and signed-stream access to authorized users in your host.

- **Memory** (`:memory`) keeps every envelope in memory for tests and examples.

The surface controller listens for `openui:envelope` on `document`, so any
transport that produces a bubbling event (or dispatches on the element) works,
and envelopes for other `message_id`s are ignored.

## The action loop

Component `onAction` and browser `toolProvider` `Query()`/`Mutation()` calls
post the same body to the single endpoint (`/openui-rails/actions` by default):

```json
{ "action": "orders.refresh", "args": {}, "surface_id": "…", "version": 3,
  "idempotency_key": "…", "confirmed": false }
```

The official component event uses `{ type, params }`; the bridge maps it to
`action` and `args`. A tool receives the handler's `value`, not the endpoint's
result wrapper. Unknown tool names still fail the server allowlist.

`confirmed: true` is a host-supplied acknowledgement, not cryptographic proof
of human consent. It is never inferred from `params` or form state. Collect
confirmation in trusted host UI. For high-risk operations, verify a signed,
server-issued approval in the authorizer as well.

The `Actions::Dispatcher` applies every gate **before any side effect**, in
order:

1. submission parse/validate
2. action is registered (allowlist — no reflection from a name to a method)
3. args match the schema (required/optional types, extra keys rejected)
4. explicit `confirmed: true` when the action is destructive
5. surface revision is current (stale protection)
6. authorizer allows it (required; fail closed)
7. idempotency claim (duplicates never run twice, replay with different args is rejected)

Idempotency keys are scoped to the server actor and tenant. The request digest
also binds the action, surface, version, arguments, and confirmation flag.
See [configuration](CONFIGURATION.md) for the shared-store contract and TTL
limits. This is not an exactly-once guarantee across expiry or process restarts.

Structured errors (JSON `{ error: { code, message } }`):

| Code | Status | Meaning |
| --- | --- | --- |
| `unknown_action` | 404 | not in the registry |
| `unauthorized` | 403 | authorizer denied, no authorizer, or unresolvable surface |
| `stale_surface` | 409 | submitted against a superseded revision |
| `replay` | 409 | idempotency key reused |
| `invalid_action` | 422 | malformed payload/args or missing confirmation |
| `csrf_failed` | 422 | invalid authenticity token |

## Message protocol

`OpenUI::Rails::Message` implements the upstream `buildMessage`/`parseMessage`
framing (marker lines beginning with `]]>openui:`). Use it to store a response
so the browser `Renderer` can read both content and context, and to strip the
markers before a stored message is sent back to a model:

```ruby
stored = OpenUI::Rails::Message.build(content: lang, context: { form: form_state }, finished: true)
OpenUI::Rails::Message.strip(stored)        # => model-safe content, no markers
OpenUI::Rails::Message.parse(stored).context
```

This is *message framing*, not an OpenUI Lang parser. Client-supplied context is
untrusted input.

## RubyLLM adapter

Optional and never required. It owns RubyLLM event normalization and delegates
sequencing/limits to the stream bridge, so a host keeps RubyLLM's own Rails
streaming pattern:

```ruby
OpenUI::Rails::Adapters::RubyLLM.stream(
  chat: chat, question: question, surface_id: surface.id
) { |envelope| broadcast(envelope) }
```

`ruby_llm` is isolated under `OpenUI::Rails::Adapters`; failures are classified
by class *name*, so no `RubyLLM` constant is referenced at load time.

## Assets and CSP

- The runtime is version-pinned and served from your app (or an exact-version
  URL you configure). Self-hosting is the default.
- You may pin subresource integrity via `config.runtime_integrity`; the fetch
  task prints the digest to use.
- To use a strict Content Security Policy, add a nonce/host for the runtime
  script you serve. This bridge adds no inline scripts. The upstream renderer
  does use inline styles and injects a loading `<style>` element. Strict
  `style-src` policies need separate validation; script SRI is not proof of
  strict-CSP compatibility.

## Accessibility

- A streaming surface is marked `aria-busy="true"` and flips to `"false"` when
  it completes (or errors), so a screen reader waits for the region to settle.
- Pass `label:` to `openui_surface` to expose the mount as a named `region`
  landmark; without a label no role is added, so unnamed containers are not
  invented.
- The mount is not `aria-hidden`. Automated checks cover named regions,
  streaming busy states, and real keyboard activation. A human screen-reader
  audit of generated content has not been performed.

## Security model

Model output is untrusted UI DSL. The controls this Gem is responsible for:

- **Allowlist only** — the browser can resolve only components and actions the
  pinned library declares, and only actions registered in the Rails registry.
- **One action path** — every write passes all seven gates above; no
  model-provided name maps to Ruby reflection.
- **Fail closed** — no authorizer means denied.
- **Rails-owned identity** — CSRF protection, session auth and per-surface
  version all come from Rails; surface ids are resolved scoped to actor/tenant.
- **Untrusted context** — client form state is never treated as a write
  confirmation, and `]]>openui:` markers are stripped before model history.
- **Pinned supply chain** — exact runtime/CLI versions, optional integrity,
  no production mutable CDN.

Report vulnerabilities privately per [`SECURITY.md`](SECURITY.md).

## Versioning and rollback

- `0.x` releases allow documented breaking changes with migration notes; the
  Ruby API is not frozen. See [`CHANGELOG.md`](CHANGELOG.md).
- The JS runtime is version-locked, and a response is stored with its
  prompt/library fingerprint, so a mismatched fingerprint is a **visible
  failure** rather than rendering old source against a new schema.
- Downgrading the Gem is the supported rollback; persisted snapshots are
  readable by previous versions where the schema is compatible, otherwise they
  degrade to a safe read-only/fallback with a diagnostic.

## Status

Version `0.1.0` was published on 2026-10-18. The public API may change between
`0.x` releases.

The audit fixed defects that the original stub-only tests missed. See
[AUDIT.md](AUDIT.md) for findings, verification evidence, and publication gates.
CI runs unit/integration tests, deterministic browser tests, the real pinned
OpenUI bundle, real Turbo/Action Cable delivery, a RubyLLM 2.1.1 SSE probe,
dependency advisory checks, and a fresh-host test of the built gem.

A live-provider smoke completed through OpenRouter on 2026-10-18; see
[`AUDIT.md`](AUDIT.md) for its scope and evidence. Releases use the verified
artifact, RubyGems Trusted Publishing, and the protected GitHub `release`
environment. See [RubyGems](https://rubygems.org/gems/openui-rails) and
[GitHub Releases](https://github.com/yorzi/openui-rails/releases) for published
versions. Hosts that redistribute the fetched browser bundle must review its
complete transitive notices as described in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

## Development

```bash
bundle install
bundle exec bin/rails db:test:prepare
bundle exec bin/rails test        # unit + integration
bundle exec bin/rails test:system # browser (needs Chrome)
bundle exec rubocop               # rubocop-rails-omakase
bundle exec gem build openui-rails.gemspec
```

See [`CONTRIBUTING.md`](CONTRIBUTING.md).

## Documentation

- [`CHANGELOG.md`](CHANGELOG.md)
- [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)
- [`CONTRIBUTING.md`](CONTRIBUTING.md)
- [`CONFIGURATION.md`](CONFIGURATION.md)
- [`UPGRADING.md`](UPGRADING.md)
- [`AUDIT.md`](AUDIT.md)
- [`RELEASING.md`](RELEASING.md)
- [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md)
- [`SECURITY.md`](SECURITY.md)

## License

Released under the [MIT License](LICENSE). OpenUI and the `@openuidev/*`
packages are MIT-licensed by Thesys ("Copyright (c) 2011-2024 Thesys Inc.");
their notices ship in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).
