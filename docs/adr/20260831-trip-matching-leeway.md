# 20260831 — Trip matching allows a few days' leeway, weighted below containment

## Context

`TripMatcher#suggested_trip` and `TripTriager#date_hint` both asked the same
question — does a date fall inside `start_date..end_date`? — with no tolerance,
and in two near-duplicate implementations.

Strict containment fails the case the hint exists for. A booking that stitches
onto a trip usually lands just outside it: a ferry the morning after a checkout,
a hotel the night before a flight. Two real bookings (a ferry and a campsite,
both continuing an existing trip) only matched because the trip's end date had
already been widened by hand first. Had it not been, they would have scored zero,
no hint would have fired, and the model would have proposed spurious new trips —
exactly the failure the hint was added to prevent.

## Decision

One scoring method on `TripMatcher`, used by both callers. Each date in the
email scores against each trip: **2 inside the span, 1 within `LEEWAY_DAYS`
(3) of either edge, 0 beyond**. Highest total wins.

Weighting adjacency below containment matters: a flat ±3-day window would let a
trip that merely abuts the booking tie with one that actually contains it.

Three consequences fall out of the design:

- **A tie returns no match.** A booking equally adjacent to the trip ending
  Friday and the one starting Monday is genuinely ambiguous; naming either would
  dress a coin flip up as a computation. The model still gets the full trip list
  and can weigh location, which is what it's good at.
- **`first_date`/`last_date` cover only the dates near *that* trip**, not every
  date in the email. A "Booking Date" line months earlier would otherwise read
  as a booking starting long before the trip does.
- **The hint says how it matched** — inside versus adjacent — rather than
  flattening both to "DATE MATCH". They're different claims and the model should
  get the true one.

Leeway before a trip's start forced a matching fix: `accept!` previously only
ever widened `end_date`, so a backwards match would have filed a segment dated
before its own trip began — the failure `suggested_end_date` already guards
against at the other edge. `suggested_start_date` and `prior_trip_start_date`
now mirror the end-date pair, and `undo_auto_file!` restores whichever moved.

## Consequences

- Bookings that continue a trip attach to it without the trip's dates needing to
  be widened by hand first, which was the point.
- Auto-filing an extend still requires a date to extend to — now at either edge.
  Without one the trip would end up not containing its own segment.
- Three days is a judgement call, not a derived number: contiguous travel is what
  this is meant to stitch together, and a week starts pulling in genuinely
  separate trips. It's one constant to change if that proves wrong.
- Widening never narrows: a suggested date inside the existing span is ignored.

## Alternatives considered

- **A flat ±N window, matched binary.** Simpler, but loses the precedence between
  a trip that contains the booking and one that merely abuts it.
- **Picking the nearest trip on a tie.** Resolves more cases automatically, at
  the cost of being confidently wrong when two trips really are equidistant.
- **Leaving adjacency entirely to the LLM.** That was the status quo, and it
  proposed a new trip for a booking starting on an existing trip's last day.
