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
- **The LLM never computes an instant.** It returns wall-clock + an IANA zone;
  `SegmentTime` resolves it, and leaves a segment **undated** rather than guess.
  Don't "helpfully" ask the model for an ISO timestamp again —
  `docs/adr/20260829-deterministic-segment-times.md`.
- **Intake shares a mailbox with other apps.** Never set `\Seen`; only ever move
  messages wander itself captured, and only into wander's own folder. Capture
  before moving. See `docs/adr/20260829-imap-intake-direct-not-bichon.md`, which
  also records why there is no per-app `travel@` intake address.
- **`AllowedSender` is not `SafeSender`.** `SafeSender` is travel providers,
  matched anywhere in a message including a forwarded body. `AllowedSender` is
  who wander may *reply* to, matched on the `From` header only. Never merge them.

## Shape

- Models: `Trip` (has_many segments, raw_emails), `Segment` (has_one qr_code,
  `links` json), `QrCode` (base64 PNG in a text column), `RawEmail`.
  `IcsCalendar` builds the feed; `ArchivePastEmailsJob` (daily, `config/recurring.yml`)
  discards emails once a trip has ended.
- Intake: `ImapMailbox` (IMAP read + move) → `EmailIntakeJob` →
  `TravelEmailClassifier` → `InboundEmail` → `TripTriager` (LLM) →
  auto-file or the Inbox. Dead ends go to `IntakeNotifier` → `IntakeMailer`,
  which replies in the original thread. `bin/rails intake:preview` dry-runs it.
- HTML UI at `/` (index) and `/trips/:id` (manage), plus a JSON API on the same
  routes — respond_to picks the format from `Accept`/`.json`.
- The calendar feed is `/calendar.ics`.

## Before changing anything

- Run `bin/ci` (rubocop, brakeman, gem/importmap audit, tests, seeds).
- Tests are Minitest + fixtures. Fixture accessors re-query, so capture an id
  *before* deleting a record you then assert is gone.
