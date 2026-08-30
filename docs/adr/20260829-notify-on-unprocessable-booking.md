# 20260829 — Reply in-thread when a captured booking can't be processed

## Context

When intake captured a booking the LLM couldn't turn into a segment, the email
landed in wander's inbox with no proposal and nothing said so. The observed case:
a campsite confirmation was captured correctly (score 13, full body), triage was
unavailable at the time, and it sat unproposed until someone filed it by hand as
a source email — which creates no segment. The booking was simply absent from
the itinerary, and nothing indicated that.

The live LLM also returns nil intermittently — one nil in three consecutive runs
over the same email during testing — so this is a routine state, not an edge
case.

## Decision

`IntakeNotifier` sends one reply, in the original email's own thread, when
processing dead-ends:

- triage is unavailable or returned nothing
- a time was read off the booking but no zone could be resolved for it
  (`20260829-deterministic-segment-times.md`), so the segment would be undated
- filing the segment raised

Explicitly **not** a trigger: low/medium confidence, or a proposed new trip.
Those are normal review states, already visible in the Inbox; mailing about them
would train the recipient to ignore the notices.

Three gates must all hold: the message hasn't been notified before
(`notified_at`), outbound mail is configured, and the sender is on the
`AllowedSender` list.

`AllowedSender` is a **separate list from `SafeSender`**, matched against the
envelope `From` only. `SafeSender` is travel providers and matches anywhere in a
message *including a forwarded body* — reusing it here would let a provider
address quoted inside a forwarded confirmation authorise a reply to that
provider. It ships empty, because the addresses are personal data and this repo
is public; an empty list means no notices, and the Settings page says so.

## Consequences

- wander sends mail, through an unauthenticated LAN SMTP relay. The from-address
  must be one the relay is allowed to send as (`MAILER_FROM_ADDRESS`).
- **Mail-loop risk.** A reply lands back in the mailbox intake reads, quoting the
  original booking, so the classifier may well capture it. `notified_at` is the
  guarantee that a given message is never notified twice; the allow-list and the
  move-out-of-INBOX behaviour are defence in depth. Don't remove the
  `notified_at` gate.
- A message with no real `Message-ID` (intake synthesises `"imap-<uid>"`) is
  notified **unthreaded** rather than with a forged `In-Reply-To`, which would
  thread with nothing and corrupt the recipient's view of the conversation.
- `notified_at` is stamped when the mail is enqueued, not delivered. A relay
  outage means one lost notice rather than a retry storm; the item is still in
  the Inbox.

## Alternatives considered

- **Reply to whoever sent the message.** Best threading, but when a provider
  mails the shared inbox directly this emails the airline or the campground
  about an internal parsing failure.
- **Always send to one fixed address.** Zero vendor risk and no list to
  maintain, but a forward from another household member notifies the wrong
  person. The allow-list gets that right and stays small.
- **A dashboard badge instead of email.** No loop risk, but it needs someone to
  look; the point is to reach a person who forwarded something and has stopped
  thinking about it.
