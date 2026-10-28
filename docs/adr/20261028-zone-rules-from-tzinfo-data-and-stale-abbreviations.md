# 20261028 — Zone rules come from tzinfo-data, and a zone's old abbreviation defers to it

Amends `20260829-deterministic-segment-times.md`.

## Context

Alberta and British Columbia stopped changing clocks on 2026-11-01: Alberta
stays on UTC−6 and BC on UTC−7 year-round. The tz database carries this from
release 2026c.

Two things in wander got it wrong.

1. **The zone rules were the container's.** `tzinfo-data` was restricted to
   Windows and JRuby, so on Linux TZInfo read the OS image's zoneinfo. The
   image's Debian package was 2025b, still falling back to standard time, so
   every Alberta or BC time after the change resolved an hour off. Nothing
   flagged it, and a development machine with newer tzdata gave different
   answers from production for the same email.
2. **A label's abbreviation was read as a fixed offset, first.** Bookings made
   before the change keep printing the old names. "Jan 3, 4:00 PM PST" on a
   Victoria hotel is 4:00 PM on Victoria's clocks, which is now UTC−7, not the
   −8 that PST stands for. An updated zone database alone doesn't fix it,
   because step 1 never consults the zone.

## Decision

1. **`tzinfo-data` is bundled on every platform.** TZInfo prefers it over
   system zoneinfo, so the zone rules are a gem version in `Gemfile.lock`,
   updated like any other dependency and identical in every environment.
2. **An abbreviation that is just the event zone's own name defers to that
   zone.** Step 1 still reads the label first, but when step 2 or 3 also finds a
   zone, and that zone went by the label's abbreviation in winter or summer of
   the event's year or the year before, the zone's current rules give the
   offset. The wall clock is what the traveller reads; the abbreviation was only
   ever there to name the zone.
3. An abbreviation the zone has **never** used still wins. That disagreement
   more likely means the model named the wrong zone (a departure's zone on an
   arrival), which is what step 1 exists to catch.

`yvr` and `yyj` join the BC row of the location table, so an airport-only
location still finds a zone to defer to.

## Consequences

- Times already stored for Alberta and BC after 2026-11-01 were an hour off and
  were corrected once; segments filed by intake were reprocessed.
- A rule change anywhere now needs only a `tzinfo-data` bump, which also shows
  up in dependency updates rather than waiting on a base-image rebuild.
- An abbreviation with no zone to defer to is still read as its fixed offset,
  so a stale "PST" with no usable zone or location stays an hour out. Adding
  the location to the table is the fix, as before.
