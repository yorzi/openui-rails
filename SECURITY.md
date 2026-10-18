# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately to **wangyaodi@gmail.com** rather than
opening a public issue. Include a description, affected version, and a
reproduction if possible. We will acknowledge receipt within a few days and
coordinate a fix and disclosure timeline with you.

## Threat model

`openui-rails` treats model output as untrusted UI DSL and keeps Rails
authoritative. The controls this project is responsible for:

- **Component allowlist.** The browser runtime resolves its declared library.
  Unknown components report renderer errors, not arbitrary code execution.
  The host must display a fallback when it receives `openui:error`.
- **Single action path.** Component `onAction` and browser `toolProvider`
  `Query()`/`Mutation()` calls both post to one endpoint and pass the same
  gates: allowlist, schema, confirmation, stale-surface, authorizer and
  idempotency. There is no mapping from a model-provided name to Ruby
  reflection.
- **Fail closed.** With no authorizer configured, an action is denied.
- **CSRF and tenancy.** The endpoint relies on Rails' forgery protection and on
  the host resolving a surface id scoped to the actor/tenant; an unresolvable
  surface is treated as unauthorized.
- **Untrusted context.** Client form state does not confer authorization.
  The host must call `Message.strip` before it sends stored framed content to a
  model. `confirmed: true` is an acknowledgement, not signed proof of consent.
- **Scoped replays.** Actor/tenant identity scopes idempotency keys. The full
  validated request binds a replay. TTL expiry and process restarts remain host
  concerns; irreversible operations need database-level safeguards.
- **Pinned assets.** The default JS/CSS assets have committed checksum/SRI pins.
  The fetch task disables npm lifecycle scripts and preserves upstream notices.
  Custom runtimes require explicit pins and separate review.
- **Library identity.** With a configured manifest, the browser checks the actual
  runtime spec before mounting. Without a manifest, that check is unavailable.

The browser bundle is trusted third-party page code, not a sandbox. Hosts must
set request/rate/provider budgets and validate CSP against upstream inline
styles. See [AUDIT.md](AUDIT.md) for verified scope and remaining release gates.

## Out of scope

Vulnerabilities in the upstream OpenUI runtime or the `@openuidev/*` packages
should be reported to Thesys. Issues in a host application's own authorization
logic are that application's responsibility, though we welcome reports of ways
this Gem could make a correct host insecure.
