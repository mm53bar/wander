# 20261028 — Cross-check the model's time zone against places the app recognises

Amends `20261028-zone-rules-from-tzinfo-data-and-iana-zones-first.md`.

## Context

Once the model's IANA zone decides a segment's time, nothing checks it. The
label's abbreviation used to act as a check, but it proved unreliable.

Two ways to guard the zone were measured against every stored booking email
plus six invented edge cases: an overnight international connection, a
forwarder in another zone, a billing address in another province, a summer
hotel labelled "(PST)", an address with no province, and a car rental at an
airport labelled "MT". That came to 27 emails, 3 runs each.

- **More prompt guidance** (per-end rules, places to ignore, abbreviations as
  hints) made it worse: 92 correct times against 99. Naming "MT" as an example
  steered the model to `America/Denver` for a Calgary rental in all three runs,
  and Denver still changes clocks. The original prompt already got every real
  and invented case right.
- **A deterministic cross-check** caught every wrong zone in those runs and,
  replayed over 201 recorded answers, flagged nothing that was right.

## Decision

1. **The prompt stays as it was.** On this evidence, extra wording adds risk and
   no accuracy.
2. **`SegmentTime.from_llm` returns a `zone_check`** when a resolved time's UTC
   offset differs from that of a place the location table recognises:
   - a flight, ferry, train, bus or transfer, against the first and last places
     its summary names, and only when it names at least two;
   - anything else, against its location.
3. **A failed check keeps the booking out of auto-filing**, and the inbox shows
   what disagreed.
4. **The location table reads places in the order the text names them.** It
   took the first matching table row, so "Calgary (YYC) to Vancouver (YVR)"
   resolved to Vancouver. A bare "on" no longer reads as Ontario.

Offsets are compared, not zone names, so `America/Edmonton` and an equivalent
zone agree.

## Consequences

- A wrong zone on a place the table knows gets a human look, not a silent
  hour's error.
- A place the table doesn't know is not checked, as before. Adding rows extends
  both the fallback and the check.
- A journey whose summary names only one place is not checked. The location
  field can't stand in for it, because the model fills it with either end.
