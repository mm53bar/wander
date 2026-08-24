# 20260823 — No authentication

## Context

This is a single-household travel planner: a trip and its segments are shared
state with no per-user ownership. There is no data that varies by who is signed
in, so there is nothing for a login to protect.

## Decision

wander ships with no authentication at all — no `User` model, no login flow, no
proxy-header trust. Every request is treated as coming from a trusted user.

## Consequences

- The app must never be deployed somewhere publicly reachable. `compose.yaml`'s
  header comment and the README say so; this is an operational responsibility,
  not something the app enforces.
- The JSON API is likewise open, which is why `ApplicationController` can waive
  CSRF for JSON requests without giving anything up — there's no session to
  forge into.
- If a future feature needs per-person state (personal trips, sharing), that's
  the trigger to revisit this — not before.

## Alternatives considered

- **Forward-auth headers from an upstream proxy (Authelia-style).** Rejected:
  adds a `User` model and a trust boundary for an app with no per-user data.
