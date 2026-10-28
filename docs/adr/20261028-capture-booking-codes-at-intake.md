# 20261028 — Capture scannable booking codes at intake

## Context

Many bookings carry a code to scan at a gate or terminal: a parkade entry QR,
a ferry barcode, a campsite pass. The app wander replaced showed them on the
segment, but its parser pulled them out; when intake moved into wander, only
the plain-text body came across, and no code is ever in the plain text.

Across the stored booking emails the codes arrive two ways:

- **An image loaded from the provider's site**, e.g. a parkade's QR generator
  URL, or one ferry barcode per booking with the confirmation number in the URL.
- **An image part inside the message**, referenced by `cid:` (campsite passes).

Airline itineraries carry none; their "e-ticket" links are web pages, and the
boarding pass arrives at check-in. The old parser matched `e-?ticket` on links
as well as images, which on these emails would fetch HTML.

## Decision

1. **`BookingCode` reads the codes when a message is captured**, from `<img>`
   sources and image parts whose URL, filename or Content-ID contains `qr` or
   `barcode`. Links are ignored. Remote images are downloaded then, while the
   provider still serves them, and only from public HTTPS hosts, as an `image/*`
   response under 512 KB: the URL comes from an email. They are kept on
   `InboundEmail#booking_codes` and cleared if triage releases the email.
2. **Filing attaches them to the segments**, as the existing one-per-segment
   `QrCode`:
   - a code whose source contains a segment's confirmation goes to that segment;
   - a lone code goes to every segment, since one code for a there-and-back
     booking opens either leg;
   - several codes that name no confirmation are left off, rather than guessed.
   A QR code already on a segment is never replaced.
3. **The segment card shows the code at its own proportions**, since barcodes
   aren't square, and tapping it opens it full screen on white for scanning.
   It is CSS only (`:target`), so it works offline in the installed app.
   `QrCode#data_uri` types the image from its bytes, since providers serve JPEG
   as often as PNG, and label it wrongly.

`intake:attach_codes[ids]` reads a claimed email's original from wander's
folder, read-only, and attaches its codes, for emails captured before this.

## Consequences

- Downloading at capture adds a network call per captured booking, never per
  inbox message, and a failed download only means no code.
- A code embedded in a PDF attachment is not read.
- A booking with several codes and no confirmation in their sources gets none
  automatically; a human can still attach one.
