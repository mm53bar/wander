require "test_helper"

class TravelEmailClassifierTest < ActiveSupport::TestCase
  SENDERS = %w[aircanada bcferries.com camis.com marriott].freeze

  def classify(from:, subject:, body:, senders: SENDERS)
    TravelEmailClassifier.new(from: from, subject: subject, body: body, safe_senders: senders).result
  end

  test "flags a direct booking by a safe sender in the header" do
    r = classify(from: "notification@aircanada.ca", subject: "Booking reference CC45XN", body: "Your flight.")
    assert r.travel?
    assert_includes r.signals, "sender:aircanada"
  end

  test "flags a forwarded booking whose safe sender is only in the body" do
    r = classify(
      from: "mike@aream.ca", subject: "Fwd: Confirmation",
      body: "Begin forwarded message:\nFrom: BC Parks <confirmations@camis.com>\nYour campsite is reserved."
    )
    assert r.travel?
    assert_includes r.signals, "sender:camis.com"
  end

  test "still catches booking language from a sender not on the list" do
    r = classify(from: "hi@newprovider.example", subject: "Your booking confirmation",
                 body: "Your reservation is confirmed. Confirmation number 123.")
    assert r.travel?
  end

  test "does not flag an ops alert mentioning travel-app" do
    r = classify(from: "alerts@jumbo.local", subject: "Container travel-app stopped",
                 body: "The travel-app container on Jumbo restarted.")
    assert_not r.travel?
  end

  test "does not flag ordinary mail, and ignored senders don't match" do
    r = classify(from: "support@fastmail.com", subject: "Welcome to Fastmail",
                 body: "Explore features. According to our guide, get started.")
    assert_not r.travel?
  end

  test "defaults to the managed SafeSender list when none is passed" do
    r = TravelEmailClassifier.new(from: "x@bcferries.com", subject: "Booking confirmation", body: "itinerary").result
    assert r.travel?  # bcferries.com is in fixtures
  end
end
