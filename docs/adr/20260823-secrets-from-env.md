# 20260823 — Secrets come from env vars, not Rails encrypted credentials

## Context

This repo is public. Rails' default encrypted-credentials workflow
(`config/credentials.yml.enc` + `config/master.key`) commits an encrypted file
to the repo and keeps the key out of it — safe in principle, but one more thing
every clone must get right, and a mistakenly-committed real value would be shared
across every fork.

## Decision

Runtime secrets — `SECRET_KEY_BASE` at minimum — are read from environment
variables (`compose.yaml`), not Rails credentials. `config/master.key` and
`config/credentials.yml.enc` are deleted and git-ignored; nothing calls
`Rails.application.credentials`. Rails 8.1 resolves `ENV["SECRET_KEY_BASE"]`
before consulting credentials, so this needs no extra code.

## Consequences

- `compose.yaml` / `docker run` must set `SECRET_KEY_BASE` explicitly — there is
  no fallback baked into the image.
- Cloning and running requires no key material beyond that one env var.
- A new feature needing a secret should add an `ENV.fetch` variable and document
  it in the README's configuration table.

## Alternatives considered

- **Rails encrypted credentials as the primary mechanism.** Rejected: heavier
  for a public repo with no ops team; every clone would fall back to an env var
  anyway for the one secret Rails requires.
