# 20260823 — Segment times: store the instant *and* the booking's own wording

## Context

Travel crosses time zones. A flight's ticket says "8:00 PM MDT"; the same
departure is a different wall-clock time in the traveller's home zone and a
different one again at the destination. A calendar feed needs an unambiguous
absolute instant, but the itinerary should read the way the booking does — a
segment shown in a foreign zone must not silently shift to the server's zone.

## Decision

Each segment stores two things per time:

- `starts_at` / `ends_at` — an absolute `datetime` (UTC), used for ordering and
  the iCalendar export.
- `starts_at_label` / `ends_at_label` — the free-text wording the booking used
  ("Mar 9, 8:00 PM MDT"), shown verbatim in the UI.

`Segment#local_date` prefers the label (parsing its month/day) and falls back to
the instant, so the calendar date badge matches the ticket even across zones.

## Consequences

- The two can disagree if entered inconsistently; the label is the source of
  truth for display, the instant for the calendar. Callers set both.
- No time-zone database of airport/city zones is needed — the label carries the
  human-facing zone, the instant carries the truth.

## Alternatives considered

- **Store only a UTC instant and render in a configured zone.** Rejected: every
  segment in a foreign zone would display shifted from its ticket.
- **Store a zone per segment and compute the label.** Rejected: needs per-segment
  zone data the booking rarely provides cleanly; the label already has it.
