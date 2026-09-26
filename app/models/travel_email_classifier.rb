# Decides whether a message from the shared inbox is a travel booking, so wander
# can capture it and leave everything else alone. Returns the matched signals so
# the UI shows *why* something was flagged.
#
# Two realities from the live inbox shape this:
#   1. Bookings are usually **forwarded** to the shared address, so the real
#      sender is in the body ("From: … <addr>"), not the `From` header — every
#      check runs over the header AND the body.
#   2. Noise like "Container travel-app stopped" contains "travel" but is not a
#      booking — so bare "travel" is never a signal.
#
# The authoritative signal is the **safe-sender list** (managed on the Settings
# page, seeded with known providers). Booking-language keywords are a secondary
# net so a provider that isn't on the list yet can still be caught for review.
#
# The mailbox is shared with other apps, and a retail order confirmation reads a
# lot like a booking ("your order is confirmed", "confirmation number", "will
# arrive"). So words that any confirmation email uses (GENERIC) never flag a
# message on their own, and stop counting at all once an unlisted sender is
# talking about an order or a shipment (SHOPPING). A listed sender overrides
# this: a ferry line's "itinerary and receipt" is still a booking.
class TravelEmailClassifier
  Result = Data.define(:travel?, :score, :signals)

  STRONG = [
    "booking confirmation", "booking confirmed", "booking reference",
    "reservation confirmation", "reservation confirmed", "your reservation",
    "your itinerary", "itinerary", "e-ticket", "eticket", "boarding pass",
    "trip confirmation", "flight confirmation", "your booking", "your stay",
    "your flight", "your trip is booked", "pnr", "check-in is now open"
  ].freeze

  WEAK = %w[
    flight hotel airline itinerary reservation campsite check-in check-out
    departure boarding terminal gate nights lodging ferry rental depart
  ].freeze

  GENERIC_STRONG = [ "is reserved", "is confirmed", "confirmation number" ].freeze

  GENERIC_WEAK = %w[arrival arrive confirmation].freeze

  SHOPPING = [
    "your order", "order confirmation", "order number", "order #", "order no.",
    "has shipped", "have shipped", "tracking number", "track your package",
    "out for delivery", "estimated delivery"
  ].freeze

  THRESHOLD = 3

  # safe_senders: lowercased match strings; defaults to the managed list.
  def initialize(from:, subject:, body:, safe_senders: SafeSender.match_values)
    @from = from.to_s.downcase
    @subject = subject.to_s.downcase
    @body = body.to_s.downcase
    @haystack = "#{@from}\n#{@subject}\n#{@body}"
    @safe_senders = safe_senders
  end

  def result
    signals = []
    score = 0

    # A known travel sender anywhere in the message (header or forwarded body).
    sender = @safe_senders.find { |s| s.present? && @haystack.include?(s) }
    if sender
      signals << "sender:#{sender}"
      score += 3
    end

    shopping = sender ? [] : SHOPPING.select { |phrase| @haystack.include?(phrase) }
    signals.concat(shopping.map { |phrase| "shopping:#{phrase}" })

    specific = phrase_score(STRONG, signals) + word_score(WEAK, signals)
    generic = phrase_score(GENERIC_STRONG, signals) + word_score(GENERIC_WEAK, signals)
    score += specific
    score += generic if shopping.empty?

    travel = score >= THRESHOLD && (sender.present? || specific.positive?)
    Result.new(travel?: travel, score: score, signals: signals.uniq)
  end

  private

  def phrase_score(phrases, signals)
    phrases.sum do |phrase|
      if @subject.include?(phrase)
        signals << "subject:#{phrase}"; 2
      elsif @body.include?(phrase)
        signals << "body:#{phrase}"; 2
      else
        0
      end
    end
  end

  def word_score(words, signals)
    words.sum do |word|
      next 0 unless @haystack.match?(/\b#{Regexp.escape(word)}\b/)
      signals << "word:#{word}"; 1
    end
  end
end
