# 20261028 — Zone rules come from tzinfo-data, and an IANA zone beats a label's abbreviation

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
2. **A label's abbreviation was read first, as a fixed offset.** An offset can't
   follow a rule change, so "Jan 3, 4:00 PM PST" on a Victoria hotel resolved to
   UTC−8 when Victoria's clocks will read 4:00 PM at UTC−7.

Step 1 of `20260829` assumed the label's abbreviation was the booking's own
wording, and so the most trustworthy source. Checked against the stored source
emails, it almost never was. Of the 31 stored labels carrying an abbreviation,
30 had none in their email; a parser in the app wander replaced had added
them. The one that did come from an email, a hotel's "4:00 p.m. (PST)", was for
an October stay, when the hotel's clocks were on PDT. The airline itineraries
that prompted this state no zone at all.

## Decision

1. **`tzinfo-data` is bundled on every platform.** TZInfo prefers it over
   system zoneinfo, so the zone rules are a gem version in `Gemfile.lock`,
   updated like any other dependency and identical in every environment.
2. **A known IANA zone decides.** The resolution order becomes: the model's IANA
   zone, then the location table, then an abbreviation in the label, then
   nothing. An IANA zone carries the rules for the date, including changes to
   them; an abbreviation is one fixed offset that is wrong whenever it is stale
   or used loosely.

`yvr` and `yyj` join the BC row of the location table, so an airport-only
location still finds a zone.

## Consequences

- Times already stored for Alberta and BC after 2026-11-01 were an hour off and
  were corrected once; segments filed by intake were reprocessed.
- A rule change anywhere now needs only a `tzinfo-data` bump, which also shows
  up in dependency updates rather than waiting on a base-image rebuild.
- Nothing now cross-checks the model's zone. If it names the wrong zone, such as
  a departure's zone on an arrival, the time is wrong even when the label says
  otherwise. Per-end zones in the prompt are what guard that.
- An abbreviation still resolves a time with no zone and no recognised location,
  so a stale one there is still an hour out. Adding the location to the table
  is the fix, as before.
