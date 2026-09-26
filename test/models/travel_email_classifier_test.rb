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

  test "does not flag a retail order confirmation from an unlisted sender" do
    r = classify(from: "orders@outfitter.example", subject: "Your order is confirmed",
                 body: "Thanks! Order confirmation number 12345. Your order will arrive in 3-5 days.")
    assert_not r.travel?
    assert_includes r.signals, "shopping:your order"
  end

  test "does not flag a shipping notice that gives an arrival date" do
    r = classify(from: "ship@outfitter.example", subject: "Your order has shipped",
                 body: "Tracking number 1Z999. Estimated arrival Oct 2. Confirmation 555.")
    assert_not r.travel?
  end

  test "generic confirmation words alone never flag a message" do
    r = classify(from: "desk@clinic.example", subject: "Your appointment is confirmed",
                 body: "Confirmation number 42. Please arrive 10 minutes early.")
    assert_not r.travel?
  end

  test "a listed sender overrides the shopping language" do
    r = classify(from: "no-reply@bcferries.com", subject: "Your itinerary and receipt",
                 body: "Order number 998. Your booking reference is B123.")
    assert r.travel?
  end

  test "an unlisted provider's booking still counts when it also says order" do
    r = classify(from: "hello@kayaktours.example", subject: "Your order is confirmed",
                 body: "Your reservation for the sunset tour. Check-in at the dock at 6pm.")
    assert r.travel?
  end

  test "defaults to the managed SafeSender list when none is passed" do
    r = TravelEmailClassifier.new(from: "x@bcferries.com", subject: "Booking confirmation", body: "itinerary").result
    assert r.travel?  # bcferries.com is in fixtures
  end
end
