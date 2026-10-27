# 20261027 — Trip extensions wait for review, and triage weighs who travels

Amends `20260825-inbox-triage-and-auto-accept.md` and
`20260831-trip-matching-leeway.md`.

## Context

`20260825` kept trip extensions in the inbox for review. A later change let a
high-confidence extend auto-file once it had a date to extend to, and the
leeway decision then made extends far more common: any booking within
`LEEWAY_DAYS` of a trip's edge now gets a DATE MATCH telling the model to treat
it as an extension.

That combination filed a different household member's booking onto someone
else's trip. One person's round trip ended at home; the next day another member
of the household started a round trip of their own, from a different city,
through that same home airport. The date match named the first trip as the only
candidate, the shared airport made the booking read as a "plausible
continuation", and the model answered with high confidence and cited the DATE
MATCH. The booking auto-filed and stretched the first trip by six days.
Nothing in the prompt said who either booking was for.

Requiring a new confirmation number doesn't help. An email that repeats a
confirmation already on a trip is resolved as a duplicate before triage runs, so
every extension triage proposes is a new booking.

## Decision

1. **Extensions never auto-file.** `InboundEmail#auto_acceptable?` accepts only a
   high-confidence assignment that fits inside an existing trip. Extends at
   either edge, and new-trip proposals, wait in the inbox. The inbox now offers
   to widen the trip at the start edge too, not only the end. Until now a
   start-only extend never reached that screen.
2. **Triage sees travellers.** Each trip in the prompt carries
   `travellers=<field or ?>`. The model reads the booking's passenger or guest
   names, ignoring whoever sent or forwarded it. When a trip names travellers
   and the booking shares none of them, the model proposes a new trip,
   whatever the dates say. An empty or count-only travellers field ("Two adults")
   gives no signal. The names the model reads become the new trip's
   `travellers`, so the next booking for them has something to match.

Matching names stays with the model. The field is free text: a first name, a
full name in capitals, "Family (4)", or blank. A string comparison in Ruby would
be wrong more often than the model.

## Consequences

- Bookings that continue a trip (a ferry the morning after checkout, a campsite
  on the last day) now take one click in the inbox, with the trip and the
  date widening pre-selected. The leeway still does its job of naming the right
  trip; it just no longer acts on it unreviewed.
- A booking for a different traveller that falls *inside* another trip's dates
  can still auto-file if the model misses the name. Travellers in the prompt is
  what guards that case, so it depends on trips having the field filled in.
- Undo still restores dates for extends that auto-filed before this change.
