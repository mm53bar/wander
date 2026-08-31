# 20260831 — One booking email yields many segments, not one

## Context

Both LLM paths extracted exactly one segment per email by construction:
`BookingParser`'s prompt said "extract ONE travel itinerary segment", and
`TripTriager`'s schema was `"segment": {…}`, singular.

That is not the shape of travel booking. A BC Ferries forward carrying two
confirmations produced one sailing and silently dropped the other — the return
leg simply never reached the itinerary, with nothing to indicate it had been
seen and discarded.

It was also a regression. The Express app this replaced turned a single Air
Canada confirmation into four flight segments (`raw_emails` id 4 → trip 7); the
rebuild lost that.

## Decision

Both prompts return `{"segments": [...]}`, one entry per distinct leg or
booking, with an explicit instruction that a return ferry is two entries and a
multi-leg flight is one per flight. All segments in an email share one trip
assignment — the email is the unit of filing, the segment is the unit of
itinerary.

`proposed_segment` and `created_segment_id` became `proposed_segments` and
`created_segment_ids`, backfilled from the singular columns. Undo removes every
segment an auto-file created, not just the first.

**An unresolvable time zone on any one segment holds the whole email back.**
Filing three legs of a four-leg booking is more confusing than filing none of
them, and the notice already exists to say why.

The Inbox lists every proposed segment before you accept, and "Draft segment
from this" renders one form per segment so individual legs can be kept or
dropped.

## Consequences

- Round-trips and multi-leg itineraries file in one action instead of needing
  the extra legs added by hand.
- The model can now over-segment as well as under-segment — splitting one stay
  into a check-in and a check-out, say. The prompt says never to emit a leg the
  email doesn't contain, and the Inbox shows the full list before anything is
  created, but the review step matters more than it did.
- `accept!` returns an array. Callers that treated it as one record needed
  updating; `InboundEmailsController#accept` reports "N segments" when there's
  more than one.
- `bin/rails "intake:reprocess[id]"` re-runs capture→triage→file for a stored
  email, undoing wander's previous auto-file first. It refuses emails filed by
  hand, since their segments may be a human's work rather than wander's.

## Alternatives considered

- **Keep one segment per email and let a human add the rest.** What was
  happening, and the failure was silent — the dropped leg left no trace.
- **File the segments that resolve and flag the rest.** Rejected: a partially
  filed booking looks complete on the itinerary while quietly missing a leg.
- **One InboundEmail per segment.** Would have kept every downstream assumption
  intact, but a booking is one message and one filing decision; splitting it
  would multiply the review work and the dedup surface.
