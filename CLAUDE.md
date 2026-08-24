# wander — standing rules

Rails 8 travel planner. Trips → segments (with optional QR code), source emails,
and an iCalendar feed. SQLite, Solid Queue in-process in Puma, Minitest with
fixtures, Tailwind + a ported custom stylesheet. **Public repo — no private data,
no secrets, no network-specific names in commits.**

## Non-negotiables

- **Secrets are env vars only.** Never add `config/credentials.yml.enc` /
  `config/master.key`, never call `Rails.application.credentials`. New secrets go
  through `ENV.fetch` and get a row in the README config table. See
  `docs/adr/20260823-secrets-from-env.md`.
- **No auth exists, and that's deliberate** (`docs/adr/20260823-no-auth-needed.md`).
  Don't deploy this publicly reachable. The JSON CSRF waiver in
  `ApplicationController` relies on there being nothing to protect.
- **No household/personal data in the repo.** `db/seeds.rb` is fictional sample
  data (generic cities, made-up confirmation codes) and must stay that way.
- **Segment times are two fields**: an absolute `starts_at`/`ends_at` (UTC, for
  ordering + the calendar) and a verbatim `*_label` string (the booking's own
  wording, for display). See `docs/adr/20260823-store-instant-and-label.md`.
  `type` is deliberately named `kind` (Active Record reserves `type` for STI).

## Shape

- Models: `Trip` (has_many segments, raw_emails), `Segment` (has_one qr_code,
  `links` json), `QrCode` (base64 PNG in a text column), `RawEmail`.
  `IcsCalendar` builds the feed; `ArchivePastEmailsJob` (daily, `config/recurring.yml`)
  discards emails once a trip has ended.
- HTML UI at `/` (index) and `/trips/:id` (manage), plus a JSON API on the same
  routes — respond_to picks the format from `Accept`/`.json`.
- The calendar feed is `/calendar.ics`.

## Before changing anything

- Run `bin/ci` (rubocop, brakeman, gem/importmap audit, tests, seeds).
- Tests are Minitest + fixtures. Fixture accessors re-query, so capture an id
  *before* deleting a record you then assert is gone.
