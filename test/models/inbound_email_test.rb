require "test_helper"

class InboundEmailTest < ActiveSupport::TestCase
  test "file_to! copies the email onto the trip and marks it filed" do
    inbound = inbound_emails(:pending_flight)
    trip = trips(:lisbon)
    assert_difference -> { trip.raw_emails.count }, 1 do
      inbound.file_to!(trip)
    end
    assert_equal "filed", inbound.reload.status
    assert_equal trip, inbound.trip
    assert_equal inbound.subject, trip.raw_emails.order(:created_at).last.subject
  end

  test "ignore! marks it ignored" do
    inbound = inbound_emails(:pending_hotel)
    inbound.ignore!
    assert_equal "ignored", inbound.reload.status
  end

  test "message_id must be unique" do
    dup = InboundEmail.new(message_id: inbound_emails(:pending_flight).message_id, received_at: Time.current)
    assert_not dup.valid?
  end

  test "received scope returns only received, newest first" do
    assert_equal InboundEmail.where(status: "received").order(received_at: :desc).to_a, InboundEmail.received.to_a
  end
end
