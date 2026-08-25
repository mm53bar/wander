require "test_helper"

class EmailIntakeJobTest < ActiveJob::TestCase
  # Minimal stand-in for BichonClient (no network).
  class FakeBichon
    def initialize(messages) = @messages = messages
    def configured? = true
    def messages_since(_since, **) = @messages
  end

  def msg(id, from:, subject:, body:)
    BichonClient::Message.new(message_id: id, from: from, subject: subject, body: body, received_at: Time.current)
  end

  test "captures only travel-related messages" do
    client = FakeBichon.new([
      msg("<t1>", from: "no-reply@bcferries.com", subject: "Your booking is confirmed", body: "Your ferry itinerary."),
      msg("<n1>", from: "support@fastmail.com", subject: "Welcome", body: "Explore your mailbox.")
    ])
    assert_difference -> { InboundEmail.count }, 1 do
      EmailIntakeJob.perform_now(client: client)
    end
    assert InboundEmail.exists?(message_id: "<t1>")
    assert_not InboundEmail.exists?(message_id: "<n1>")
  end

  test "is idempotent across runs (dedup by message_id)" do
    client = FakeBichon.new([ msg("<t1>", from: "no-reply@bcferries.com", subject: "Booking confirmation", body: "Your itinerary and booking reference.") ])
    EmailIntakeJob.perform_now(client: client)
    assert_no_difference -> { InboundEmail.count } do
      EmailIntakeJob.perform_now(client: client)
    end
  end

  test "does nothing when the client is not configured" do
    unconfigured = Class.new { def configured? = false }.new
    assert_no_difference -> { InboundEmail.count } do
      EmailIntakeJob.perform_now(client: unconfigured)
    end
  end
end
