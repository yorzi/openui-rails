# Security policy

## Reporting a vulnerability

Please report vulnerabilities privately to **wangyaodi@gmail.com** rather than
opening a public issue. Include a description, affected version, and a
reproduction if possible. We will acknowledge receipt within a few days and
coordinate a fix and disclosure timeline with you.

## Threat model

`openui-rails` treats model output as untrusted UI DSL and keeps Rails
authoritative. The controls this project is responsible for:

- **Component allowlist.** The browser runtime can only resolve components and
  actions the pinned library declares; unknown components fall back rather than
  executing.
- **Single action path.** Component `onAction` and browser `toolProvider`
  `Query()`/`Mutation()` calls both post to one endpoint and pass the same
  gates: allowlist, schema, confirmation, stale-surface, authorizer and
  idempotency. There is no mapping from a model-provided name to Ruby
  reflection.
- **Fail closed.** With no authorizer configured, an action is denied.
- **CSRF and tenancy.** The endpoint relies on Rails' forgery protection and on
  the host resolving a surface id scoped to the actor/tenant; an unresolvable
  surface is treated as unauthorized.
- **Untrusted context.** Client-sent form state is never treated as an
  Active Record write confirmation, and `]]>openui:` markers are stripped
  before a stored message is sent back to a model.
- **Pinned assets.** The JS runtime is version-pinned and optionally integrity
  checked; the prompt CLI is pinned and runs with telemetry disabled.

## Out of scope

Vulnerabilities in the upstream OpenUI runtime or the `@openuidev/*` packages
should be reported to Thesys. Issues in a host application's own authorization
logic are that application's responsibility, though we welcome reports of ways
this Gem could make a correct host insecure.
