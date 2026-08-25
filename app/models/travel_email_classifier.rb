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
class TravelEmailClassifier
  Result = Data.define(:travel?, :score, :signals)

  STRONG = [
    "booking confirmation", "booking confirmed", "booking reference",
    "reservation confirmation", "reservation confirmed", "your reservation",
    "your itinerary", "itinerary", "e-ticket", "eticket", "boarding pass",
    "trip confirmation", "flight confirmation", "your booking", "your stay",
    "your flight", "your trip is booked", "is reserved", "is confirmed",
    "confirmation number", "pnr", "check-in is now open"
  ].freeze

  WEAK = %w[
    flight hotel airline itinerary reservation campsite check-in check-out
    departure arrival boarding terminal gate nights lodging ferry rental
    confirmation depart arrive
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
    if (hit = @safe_senders.find { |s| s.present? && @haystack.include?(s) })
      signals << "sender:#{hit}"
      score += 3
    end

    STRONG.each do |phrase|
      if @subject.include?(phrase)
        signals << "subject:#{phrase}"; score += 2
      elsif @body.include?(phrase)
        signals << "body:#{phrase}"; score += 2
      end
    end

    WEAK.each do |word|
      if @haystack.match?(/\b#{Regexp.escape(word)}\b/)
        signals << "word:#{word}"; score += 1
      end
    end

    Result.new(travel?: score >= THRESHOLD, score: score, signals: signals.uniq)
  end
end
