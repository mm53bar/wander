# 20260823 — Hand-rolled iCalendar writer, no gem

## Context

The app exposes a subscribable calendar feed of every timed segment. The
iCalendar (RFC 5545) we need is small: one `VEVENT` per segment with a UID,
start/end, summary, location, and description.

## Decision

`IcsCalendar` (a plain model) emits the feed directly as strings — CRLF line
endings, UTC `DTSTART`/`DTEND`, and RFC 5545 text escaping for `; , \ \n`. No
calendar gem is used.

## Consequences

- One small, well-tested class (`test/models/ics_calendar_test.rb`) with no
  dependency to track or audit.
- If the feed ever needs recurrence rules, alarms, or timezone components
  (`VTIMEZONE`), reconsider — that's where a gem starts to earn its place.

## Alternatives considered

- **The `icalendar` gem.** Rejected for now: more surface than the handful of
  lines the current feed needs. The escaping and format are covered by tests.
