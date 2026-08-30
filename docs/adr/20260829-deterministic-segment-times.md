# 20260829 — The LLM names a time zone; Ruby computes the instant

## Context

Both LLM paths asked the model for `starts_at` as an ISO8601 **instant**. That
requires identifying a zone *and* applying a DST-correct offset. The model does
the first well and the second inconsistently: the same BC Parks confirmation —
whose own wording is `Check In: 1:00 p.m.` with no zone anywhere — produced
`-07:00` on one run and `-06:00` on the next. Nothing caught it. The label is
verbatim and looked right, so only the calendar feed and the sort order were
wrong, silently, by an hour.

This is a division-of-labour problem, not a prompt-quality one. Naming
"Parksville BC → `America/Vancouver`" is recall. Turning a wall clock into an
instant is arithmetic over a zone database.

## Decision

The model returns `*_at_local` (wall clock, no offset) and `*_time_zone` (IANA),
per timestamp — a departure and an arrival can differ. `SegmentTime` computes the
instant, resolving the zone in a fixed order, first hit wins:

1. a zone abbreviation in the booking's own wording (`"Sep 5, 3:00 PM PDT"`)
2. the model's IANA zone, only if `ActiveSupport::TimeZone` resolves it
3. a static table keyed off the segment's location
4. nothing — `starts_at` stays nil and the segment is left **undated**

Any offset the model attaches anyway is discarded rather than trusted.
Ambiguous abbreviations (`CST`, `IST`, `BST`) are deliberately absent from the
step-1 table: each means different offsets in different parts of the world, so
they fall through to a step that can tell the difference.

Step 4 is the point of the whole thing. An undated segment is visible — it is
missing from the calendar and triggers a manual-handling notice — where a wrong
hour is not.

## Consequences

- Repeated runs over the same email now produce identical instants; verified
  against the live model.
- A booking in a location the table doesn't cover, with no zone in its wording
  and no usable zone from the model, yields an undated segment for review rather
  than a plausible wrong time. That is the intended failure.
- `ZONE_BY_LOCATION` is a hand-maintained list biased to where this household
  travels. It is a fallback, not a geocoder; adding rows is expected.
- This extends the reasoning in `20260823-store-instant-and-label.md`: the label
  was already the trusted half for display, and is now also the primary source
  for resolving the instant.

## Alternatives considered

- **Keep asking for an instant, with a better prompt.** The failure is silent
  and intermittent, which is the worst combination to defend with wording.
- **A static location→zone table only, no model input.** Fully deterministic,
  but anywhere unlisted yields an undated segment, including places the model
  would have named correctly. Kept as step 3 rather than the whole answer.
- **Trust only a zone stated in the email.** Strictest, and would have left the
  booking that prompted this work undated — it states no zone at all.
- **Geocode the location and look up the zone.** A network dependency and an API
  key for a problem two lookup steps already solve.
