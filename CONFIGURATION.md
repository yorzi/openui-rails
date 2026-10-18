# Configuration

Configure the bridge in `config/initializers/openui.rb`. Rails owns identity,
authorization, stream subscriptions, persistence, and snapshot recovery.

| Setting | Default | Contract |
| --- | --- | --- |
| `transport` | `:turbo` | Factory preference: `:turbo`, `:action_cable`, or `:none`. Pass it explicitly to `Transports.build`; it does not create a subscription. |
| `library_spec_path` | `nil` | JSON manifest from the exact runtime library. Enables server and browser fingerprint checks. |
| `prompt_path` | `nil` | Prompt generated from that same library. |
| `runtime_assets` | `:self_hosted` | Use `:external` only with explicit exact-version URLs. |
| `local_runtime_path` | `"/openui"` | Public URL directory for self-hosted assets. |
| `runtime_version` | pinned `0.2.1` | The fetch task accepts only the checksum-locked version. Other versions are unverified. |
| `runtime_url` | derived self-hosted JS URL | Explicit override for a host-built or external runtime. |
| `runtime_integrity` | pinned hash for the default runtime | Override for another JS asset. No default hash is assumed for custom URLs. |
| `runtime_stylesheet_url` | derived self-hosted CSS URL | Required when using `:external` and `openui_stylesheet_tag`. |
| `runtime_stylesheet_integrity` | pinned hash for the default runtime | Override for another CSS asset. |
| `actions_endpoint` | `"/openui-rails/actions"` | Must match the host engine mount. |
| `stream_byte_limit` | `1_048_576` | Positive integer; enforced by server writer and browser. |
| `pending_byte_limit` | `32_768` | Positive byte-based flush threshold, at most the stream limit. Lower it for smaller, more frequent updates. There is no timer-based flush. |
| `idempotency_ttl` | `900` seconds | Finite positive number. Replays are protected only within the store's lifetime and TTL. |
| `idempotency_store` | process-local `MemoryStore` | Use a shared atomic store for multiple processes. See the contract below. |
| `idempotency_scope` | derived actor/tenant identity | Optional callable receiving `Invocation`; return a stable, JSON-serializable namespace for custom identity types. |
| `actor_resolver` | host `current_user`, if available | Callable receiving the engine controller. Host authentication filters are inherited. |
| `surface_resolver` | `nil` | Callable `(surface_id, actor:, context:)`; return the scoped surface, or `nil` to deny. Without it, the authorizer owns resource/version checks. |
| `authorize_action` | `nil` | Global authorizer receiving `Invocation`. Missing authorization denies the action. Per-action `authorize:` takes precedence. |
| `on_error` | `nil` | Server stream-error hook `(error, message_id:)`. Do not log credentials or unredacted provider requests. |
| `action_registry` | lazy `Actions::Registry` | Allowlisted action definitions. |

`library_name` and `surface_id_param` are legacy metadata settings. They do not
select a runtime library or change the endpoint's `surface_id` wire key.

After you create the library files, call
`OpenUI::Rails.configuration.validate!` to check required configuration.
Boot does not call it automatically, so setup tasks can run before files exist.

## Shared idempotency store

The dispatcher supplies a SHA-256 key scoped to server actor and tenant identity.
It supplies a digest of the entire validated request separately.

```ruby
claim(key, ttl:, digest:)
# => [:claimed, nil, digest, claim_token]       # this request owns execution
# => [:pending, nil, stored_digest, token]     # execution is in progress
# => [:replay, result, stored_digest, token]   # completed, including nil/false

record(key, result, claim_token: token)
```

Implement `claim` atomically. Make `claim_token` unique for every new claim.
Ignore a `record` call whose token no longer owns the key. Preserve completed
`nil` and `false` results instead of treating them as pending.

The default identity is `[class, id]` for records and `[class, value]` for scalar
identities. Unsupported identity objects need `idempotency_scope`. Scope must
come from trusted server state, not a client-supplied user or tenant ID.

A failed handler leaves a pending claim until expiry because its side effects
may already have happened. A handler that outlives the TTL can overlap a later
claim. Choose a suitable TTL and enforce business-level uniqueness or
transactions for irreversible operations. Process-local memory does not survive
restarts and cannot coordinate separate workers.

## Browser errors and recovery

Listen for `openui:error` to show a host-owned error or fallback. Listen for
`openui:snapshot-required` to fetch an authorized, authoritative snapshot.
The bridge emits these events; it does not implement the host's fallback UI,
snapshot endpoint, reconnection policy, or persistence.

The action bridge rejects authentication redirects and non-JSON, malformed, or
mismatched results. An expired-session redirect emits `unauthorized`; a broken
response contract emits `invalid_response`. Host callbacks may still redirect
HTTP requests, but a redirect is never a successful JSON action result.

Configure a matching manifest in production. Without one, the bridge cannot
verify that the model prompt, stored output, and runtime library agree.
