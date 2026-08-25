# Decides whether a message pulled from the shared casey@ inbox is a travel
# booking, so wander can capture it and leave everything else alone.
#
# Deliberately a transparent heuristic (not an LLM): it returns the matched
# signals so the UI can show *why* something was flagged and the rules can be
# tuned. Two realities from the live inbox shape the design:
#   1. Bookings are usually **forwarded** to casey@, so the real sender is in the
#      body ("From: ... <addr>"), not the `From` header — we scan both, and pull
#      the forwarded sender's domain out of the body.
#   2. Noise like "Container travel-app stopped" contains the word "travel" but
#      is not a booking — so bare "travel" is never a signal; we key off booking
#      language and known travel senders.
class TravelEmailClassifier
  Result = Data.define(:travel?, :score, :signals)

  # Sender domains (or fragments) that reliably send trip bookings. Matched in
  # the From header and anywhere in the body (covers forwards).
  SENDER_DOMAINS = %w[
    aircanada westjet flyflair porterairlines united.com delta.com aa.com
    british-airways ba.com klm.com lufthansa airfrance emirates qatarairways
    ryanair easyjet southwest.com jetblue
    viarail amtrak eurostar trainline
    bcferries
    marriott hilton hyatt ihg.com accor.com booking.com expedia hotels.com airbnb
    vrbo agoda hostelworld
    enterprise.com hertz avis.com budget.com turo.com
    tripit kayak priceline travelocity
    camis.com reserveamerica recreation.gov bcparks parkscanada
  ].freeze

  # Strong booking phrases (worth crossing the bar on their own in a subject).
  STRONG = [
    "booking confirmation", "booking confirmed", "booking reference",
    "reservation confirmation", "reservation confirmed", "your reservation",
    "your itinerary", "itinerary", "e-ticket", "eticket", "boarding pass",
    "trip confirmation", "flight confirmation", "your booking", "your stay",
    "your flight", "your trip is booked", "is reserved", "is confirmed",
    "confirmation number", "booking reference number", "pnr", "check-in is now open"
  ].freeze

  # Weak words: corroborating travel vocabulary. Several together add up.
  WEAK = %w[
    flight hotel airline itinerary reservation campsite check-in check-out
    departure arrival boarding terminal gate nights lodging ferry rental
    confirmation depart arrive
  ].freeze

  THRESHOLD = 3

  def initialize(from:, subject:, body:)
    @from = from.to_s.downcase
    @subject = subject.to_s.downcase
    @body = body.to_s.downcase
    @haystack = "#{@from}\n#{@subject}\n#{@body}"
  end

  def result
    signals = []
    score = 0

    # Known travel sender — in the header or (for forwards) the body.
    if (domain = SENDER_DOMAINS.find { |d| @haystack.include?(d) })
      signals << "sender:#{domain}"
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
