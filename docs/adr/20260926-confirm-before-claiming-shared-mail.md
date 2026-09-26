# 20260926 — Claim shared mail only once triage confirms it's a booking

Amends `20260829-imap-intake-direct-not-bichon.md`.

## Context

A second app now reads the same shared mailbox, looking for purchase receipts,
and follows the same rules wander does: peek, never set `\Seen`, and move only
what it claims into its own folder.

That exposed a gap. wander moved everything its keyword classifier flagged, and
a retail order confirmation reads like a booking. "Your order is confirmed …
confirmation number … will arrive" scored 6 against a threshold of 3, so wander
would pull a receipt into its own folder before the other app ever saw it.
Whichever app polled first got it.

## Decision

Two changes, both so that wander only takes mail it is sure is its own:

1. **The classifier stops mistaking orders for bookings.** Words any
   confirmation uses (`is confirmed`, `confirmation number`, `arrive`,
   `arrival`, `confirmation`) never flag a message on their own. They stop
   counting entirely once an unlisted sender uses order or shipping language
   (`your order`, `has shipped`, `tracking number`, …). A safe sender overrides
   this, because real bookings say "itinerary and receipt".
2. **Triage confirms before intake moves anything.** The triage prompt first asks
   whether the email is a travel booking. Intake captures a flagged message,
   triages it, and moves it into wander's folder only when:
   - triage read it as a booking,
   - it repeats a recorded booking, or
   - a human filed it.

   An explicit "not a booking" marks the row `released`. The body is dropped and
   the Message-ID kept, so later passes skip the message without asking the LLM
   again. The message itself stays in INBOX. While the LLM is unreachable, the
   message also stays in INBOX and is triaged again on the next pass. An outage
   (a timeout, a 408/429, a 5xx) doesn't count toward the triage attempts, so
   however long it lasts it can't exhaust them; only an unusable answer does.

With no LLM configured at all, the classifier decides alone, as before.

## Consequences

- A classifier misfire now costs one LLM call rather than another app's mail.
  Tuning the classifier mostly controls how many of those calls are made.
- A booking whose triage attempts run out stays in INBOX. It still appears in
  wander's inbox, and filing it there by hand lets the next pass move it.
- Mail a human marks "ignored" stays in INBOX instead of being moved.
- With two apps, "each app classifies, then claims only what it's sure of" still
  works. The central router in the earlier ADR's alternatives is still the
  direction to take if a third mail-driven app appears.

## Alternatives considered

- **Classifier tuning alone.** Cheaper, but any threshold leaves a margin
  where a misfire takes another app's mail. With the LLM gate, a misfire costs
  nothing but the call.
- **Reading the other app's folder in case wander wants something from it.**
  Couples the apps. A misfile is fixed in the app that made it.
