# 20260829 — Read the mailbox directly over IMAP, and route mail app-side

Supersedes `20260825-email-intake-via-bichon.md`.

## Context

Intake originally read the shared mailbox through the Bichon email archiver's
HTTP API, so wander held no mail credentials. That made sense when the mailbox
was on Gmail, where per-app access is genuinely awkward to configure. The domain
has since moved to Fastmail, where an app password is one page in the settings,
and a sibling app on the same host already polls this very mailbox that way. The
workaround outlived the problem it solved.

Two things also turned out to need more than an envelope summary:

1. **Threading a reply** (see `20260829-notify-on-unprocessable-booking.md`)
   requires the original `Message-ID` and `References`. Bichon's envelope
   exposes a `message_id` field and *synthesises* `"bichon-<id>"` when the header
   is absent — a value that threads with nothing if it reaches `In-Reply-To`.
2. **Getting mail out of the way.** wander's captures accumulated in a shared
   INBOX that other tooling also reads, so every consumer kept re-examining
   messages wander had already dealt with.

A second question rode along with this: whether to give wander its own intake
address (`travel@`) with a server-side rule, the way the sibling app does. It was
rejected — see below.

## Decision

`ImapMailbox` polls the mailbox directly with `net/imap`. Two rules follow from
the mailbox being shared:

- **Never set `\Seen`.** Messages are fetched `BODY.PEEK[]`. Read state belongs
  to whoever else reads that inbox.
- **Move what wander claims** into its own folder (`INTAKE_ARCHIVE_MAILBOX`,
  default `Wander`), so what remains in INBOX is by definition not wander's and
  no other consumer has to step over it. Capture happens *before* the move: if
  storing fails the message stays put rather than vanishing from a mailbox other
  people read.

A message wander already has is moved out without being captured twice, which is
what carries the existing Bichon-era rows across the transition.

**No per-app intake address.** An address can legitimately carry information the
app cannot infer — the sibling app's `3days@` slug encodes *when* to remind you,
which exists nowhere else in the message. `travel@` would encode only *which app
should handle this*, which wander can already determine: it classified the
booking that prompted this work at score 13. Making a human supply it is
offloading work from a place that can do it to a place that cannot scale — and
at N apps, per-app addresses become a routing table kept in human memory. The
classifier is what buys a single address, so it stays.

## Consequences

- wander now holds a Fastmail app password (`IMAP_PASSWORD`) and has write
  access to a live mailbox. The blast radius is bounded by only ever moving
  messages it captured, into its own folder.
- **Moving is only safe because the destination is wander's own folder.** Do not
  "simplify" this by pointing the move at a shared folder or by marking `\Seen`
  in INBOX instead.
- Bichon is no longer in wander's path. It remains the archive and search
  surface for other tooling, and the original Gmail rationale still holds for the
  accounts that haven't migrated — this is wander not depending on it, not a
  case for removing it.
- Bichon syncs only INBOX and Sent for this account, so mail wander moves to
  `Wander` drops out of Bichon's search. Add that folder to Bichon's sync if
  that archive matters.
- Latency improves: the Bichon path added its own ~10-minute sync ahead of
  wander's 15-minute poll.
- The classifier is now the only thing standing between the shared inbox and
  wander's inbox, and its margin is thin — two of the three captures to date
  scored 4 against a threshold of 3. Misfires are recoverable (the message is
  misfiled into `Wander`, not lost) but the threshold deserves revisiting once
  there is more mail to tune against.

## Alternatives considered

- **Stay on Bichon.** Viable: its `download-message` endpoint returns full raw
  RFC822, so threading alone did not force the move. Rejected once the Gmail
  rationale was gone — "doesn't block us" is not the same as earning its place,
  and folder-scoping is awkward through it (`search-messages` has no mailbox
  filter).
- **Read INBOX but never write, tracking a UID high-water mark.** Avoids write
  access entirely, but leaves every claimed message sitting in the shared inbox
  for other consumers to keep re-examining. Moving is the politer neighbour.
- **A dedicated `travel@` alias plus a server-side rule.** Makes scope
  deterministic and would largely retire the classifier, at the cost of a new
  address to remember and the precedent that every future mail-driven app gets
  one. Rejected on that precedent; see the Decision.
- **One shared intake address with a central router** dispatching to apps that
  subscribe. The version that actually scales, and the direction to head if the
  household adds more mail-driven apps. Not worth the machinery at two.
