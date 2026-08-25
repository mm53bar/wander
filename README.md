# wander

Trip planning with segments, QR codes, and calendar export. Rails 8 + SQLite,
server-rendered, no build step beyond Tailwind. Installable as a PWA.

A trip has a date range and a list of **segments** — flights, hotels, trains,
activities, anything — each with an emoji, a summary, optional times, a location,
a confirmation code, and links. Segments can carry a **QR code** (a boarding
pass, ticket, etc.), the whole itinerary exports as a **subscribable calendar
feed**, and the source booking **emails** can be stashed against a trip and are
auto-archived once the trip is over.

## Features

- Trips with start/end dates, destination, travellers, and booking reference
- Segments with emoji types, start/end times, location, confirmation, and links
- QR code storage per segment (booking passes, tickets)
- Subscribable iCalendar feed at `/calendar.ics`
- Source-email ingestion with automatic archiving after a trip ends
- Travel-email intake: scans a shared mailbox (via the Bichon archiver), identifies booking emails, and files them for review
- Managed **safe-sender list** (Settings page) drives travel detection — matched in the body too, for forwarded bookings
- JSON API alongside the HTML UI for programmatic ingestion
- Installable PWA with offline-friendly caching

## Local development

Requires Ruby (see `.ruby-version`).

```bash
bin/setup            # installs gems, prepares the database, seeds sample data
bin/dev              # starts the app + Tailwind watcher on http://localhost:3000
```

`bin/rails db:seed` loads a few fictional sample trips so a fresh checkout shows
something. Data lives in `storage/` (git-ignored).

## Tests, lint, security

```bash
bin/rails test       # Minitest with fixtures
bin/rubocop          # rails-omakase style
bin/brakeman         # static security analysis
bin/ci               # everything CI runs, in one go
```

## Configuration

All configuration is environment variables — this repo is public and commits no
secrets (see `docs/adr/20260823-secrets-from-env.md`).

| Variable | Required | Purpose |
|---|---|---|
| `SECRET_KEY_BASE` | yes (production) | Rails session/cookie signing key. `openssl rand -hex 64` |
| `TZ` | no (defaults `UTC`) | Time zone for display and the calendar feed |
| `RAILS_MAX_THREADS` | no (defaults `3`) | Puma threads; also sizes the DB pool |
| `BICHON_URL` | for email intake | Base URL of the Bichon email archiver (read API) |
| `BICHON_API_TOKEN` | for email intake | Bearer token for Bichon |
| `BICHON_ACCOUNT_ID` | for email intake | Bichon account id of the shared inbox to scan |
| `EMAIL_INTAKE_LOOKBACK_DAYS` | no (defaults `30`) | How far back each intake run scans |

There is **no authentication** by design (`docs/adr/20260823-no-auth-needed.md`),
so only run it somewhere that isn't publicly reachable — behind an
internal-only reverse proxy or bound to a private network.

## Deploy

The image builds and publishes to GHCR on every push to `main`
(`.github/workflows/build.yml`). Run it with the provided `compose.yaml`: set the
storage volume path, the `user:` UID:GID that owns it, and `SECRET_KEY_BASE`.
One container runs both the web server and the background jobs — Solid Queue runs
in-process inside Puma in production, so there is no separate worker.

## Architecture notes

See `docs/adr/` for the decisions that shaped this — no-auth, secrets-from-env,
how segment times are stored (an absolute instant plus the booking's own wording),
and the hand-rolled iCalendar writer.
