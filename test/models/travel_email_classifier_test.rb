require "test_helper"

class TravelEmailClassifierTest < ActiveSupport::TestCase
  def classify(from:, subject:, body:)
    TravelEmailClassifier.new(from: from, subject: subject, body: body).result
  end

  test "flags a direct airline booking by sender" do
    r = classify(from: "notification@notification.aircanada.ca",
                 subject: "Air Canada - Booking reference: CC45XN", body: "Your flight details.")
    assert r.travel?
    assert(r.signals.any? { |s| s.include?("aircanada") })
  end

  test "flags a forwarded booking whose real sender is in the body" do
    # The classic case: forwarded to casey@, so From is a person and the real
    # sender + booking language live in the body.
    r = classify(
      from: "mike@aream.ca", subject: "Fwd: Confirmation",
      body: "Begin forwarded message:\nFrom: BC Parks <confirmations@camis.com>\n" \
            "Your campsite is reserved. Reservation number 27-111."
    )
    assert r.travel?
    assert(r.signals.any? { |s| s.include?("camis.com") })
  end

  test "does not flag an ops alert that merely contains the word travel-app" do
    r = classify(from: "alerts@jumbo.local", subject: "Fwd: [Jumbo.local] Container travel-app stopped",
                 body: "The container travel-app on Jumbo has stopped and been restarted.")
    assert_not r.travel?
  end

  test "does not flag ordinary mail" do
    r = classify(from: "support@fastmail.com", subject: "Welcome to Fastmail",
                 body: "Here are some features to explore in your new mailbox.")
    assert_not r.travel?
  end

  test "short domain fragments do not false-match ordinary words" do
    # 'accor' must not match 'according', 'klm' must not match mid-word.
    r = classify(from: "team@example.com", subject: "Notes",
                 body: "According to the plan, we will follow up next week.")
    assert_not r.travel?
  end
end
