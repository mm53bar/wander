# 20260825 — Inbox triage: confirmation match, LLM assignment, auto-accept policy

## Context

Captured booking emails should become itinerary segments on the right trip with
as little manual work as possible — but wrong auto-actions (mis-dated segments,
spurious new trips) are costly. We measured an LLM (gpt-oss:20b-cloud) against
the real source emails to decide how much to trust it.

## Decision

Two layers, in order:

1. **Confirmation match (deterministic).** If a booking's confirmation number
   already appears on a segment, it's recorded — the email clears itself
   (`TripMatcher#duplicate_trip`). No LLM. This also resolves split-trip cases
   precisely.
2. **LLM triage (`TripTriager`).** For genuinely-new bookings, one call gets the
   trips (with their segments/locations) and the email, and returns the extracted
   segment plus an assignment: an existing trip (optionally **extending** its end
   date), or a proposed **new trip**, with a confidence and reason.

**Auto-accept policy (data-driven):** on the real emails, every high-confidence
assignment to an existing trip that fit *within* it was correct; the only
model/human divergence was a new-trip proposal (a judgment call). So:

- **Auto-file** high-confidence assignments to an existing trip that don't extend
  it — the segment is created and the email filed, with an **Undo** in the inbox.
- **Review** everything else — new-trip proposals, trip extensions, and
  medium/low confidence — in the inbox, where Accept materializes the proposal
  (creating the new trip / extending dates as needed) and the trip can be
  overridden.

Including each trip's **segments** in the prompt (not just its date envelope) was
what let the model reason about geographic/temporal continuity — e.g. attaching a
Parksville campsite that starts on the trip's last day as an *extension* rather
than a new trip.

## Consequences

- Most bookings file themselves correctly; the risky/subjective ones wait for a
  click. Auto-files are reversible (Undo deletes the segment).
- Segment extraction and assignment reuse the one OpenAI-compatible `LlmClient`;
  no new dependency.
- Filing no longer duplicates into `raw_emails`: a filed `InboundEmail` is itself
  the source record, shown on the trip alongside migrated `raw_emails`.

## Alternatives considered

- **Full auto (create everything, incl. new trips).** Rejected: the data showed
  new-trip/extend are exactly where judgment differs.
- **Full manual (always review).** Rejected: the within-trip high-confidence
  matches were reliable enough to file automatically, with Undo as the safety net.
