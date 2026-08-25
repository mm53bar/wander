# 20260825 — Identify travel email by reading the Bichon archive, not IMAP

## Context

Booking confirmations arrive at a shared mailbox (`casey@…`) that also carries
unrelated mail, and they're usually **forwarded** there — so the real sender and
the booking details are in the message *body*, not the `From` header. The
household already runs **Bichon**, a self-hosted read-only email archiver that
syncs that mailbox from Fastmail and exposes a full-text HTTP API. wander needs
to pull the travel-related messages out and leave the rest alone.

## Decision

- **Read through Bichon's API, not IMAP.** `BichonClient` calls
  `POST /api/v1/search-messages` for the configured account; the envelope's
  `text` field already carries the body, so no second fetch is needed. wander
  holds no mailbox credentials and never mutates the mailbox (Bichon is
  read-only against the provider). Sending, if ever needed, would go through the
  LAN SMTP relay — not Bichon.
- **Classify with a transparent heuristic, not an LLM.** `TravelEmailClassifier`
  scores known travel senders (matched in the header *and* the body, to catch
  forwards) plus booking language, and returns the matched signals so the UI can
  show *why* a message was flagged and the rules can be tuned. Calibrated against
  the live inbox and the old app's stored booking emails: it caught every real
  booking (ferry, air, hotel, campsite, forwarded reservations) with no false
  positives, and deliberately ignores ops noise like "Container travel-app
  stopped" (bare "travel" is never a signal).
- **Capture only travel mail into an inbox for review.** `EmailIntakeJob`
  (recurring) stores travel-classified messages as `InboundEmail` records,
  deduped by `Message-ID`. A human files one onto a trip (it becomes a source
  email) or dismisses a false positive. Turning an email into structured
  segments stays a human step for now — the seam for a future parser.

## Consequences

- No IMAP credentials in wander; one env token (`BICHON_API_TOKEN`) plus
  `BICHON_URL` and `BICHON_ACCOUNT_ID`. Not configured → the job no-ops, so
  dev/CI stay quiet.
- The classifier is intentionally simple and will occasionally miss an unusual
  sender; because signals are shown and nothing is auto-filed, misses/false
  positives are visible and cheap to correct. An LLM classifier (local Ollama is
  available) is the natural upgrade if the heuristic proves too blunt.
- wander re-scans a rolling look-back window each run; `Message-ID` dedup makes
  that idempotent.

## Alternatives considered

- **Direct Fastmail IMAP poll (like blip).** Rejected: blip owns a dedicated
  folder and consumes it; casey@ is shared, and Bichon already centralizes
  read-only access without spreading mailbox credentials into every app.
- **Auto-create trips/segments from parsed email.** Deferred: reliable parsing
  of arbitrary booking emails is an LLM-shaped problem; capture-and-review is a
  safe first step that already delivers the "identify travel email" goal.
