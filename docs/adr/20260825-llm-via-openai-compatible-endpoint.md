# 20260825 — LLM features via an OpenAI-compatible endpoint, configured by env

## Context

Turning a booking email into an itinerary segment (what the old nanoclaw pipeline
did) needs an LLM. This repo is public and ships in a Docker image, so it can't
carry a provider, endpoint, model, or key — and different deployments will want
different backends (a local Ollama, an Ollama cloud model, or another provider).

## Decision

- **One integration surface: the OpenAI-compatible `/v1/chat/completions` API.**
  `LlmClient` (plain Net::HTTP) targets it with `response_format: json_object`.
  Ollama — local *and* cloud — speaks this, as do most providers, so the same
  code works everywhere and the **model name** selects local vs cloud.
- **All configuration is env:** `LLM_BASE_URL`, `LLM_MODEL`, optional
  `LLM_API_KEY`. The repo/compose ship placeholders only. Unconfigured →
  `LlmClient#configured?` is false and the LLM features (the "Draft segment"
  button) simply don't render. Same graceful-degradation shape as the Bichon
  email config.
- **Human-in-the-loop.** `BookingParser` proposes a segment; it's rendered in the
  normal segment form for review and only saved on submit. Any parse/HTTP failure
  degrades to manual entry, never a raised error or a silently-wrong save.

## Consequences

- Deployments point `LLM_BASE_URL` at whatever they run (e.g. a LAN Ollama's
  `/v1`) and pick a model; cloud vs local is a config change, not a code change.
- No SDK/provider lock-in; no secrets in the repo.
- Adding more LLM features later reuses `LlmClient` and the same env.

## Alternatives considered

- **A provider SDK (ruby-openai, etc.).** Rejected: more dependency than a single
  JSON POST needs, and would still be reconfigured per deployment.
- **Native Ollama API (`/api/chat`).** Rejected in favour of the OpenAI-compatible
  path so non-Ollama backends work unchanged.
