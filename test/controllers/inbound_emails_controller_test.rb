require "test_helper"

class InboundEmailsControllerTest < ActionDispatch::IntegrationTest
  test "index lists received inbound emails" do
    get inbound_emails_path
    assert_response :success
    assert_select "h1", text: /Travel inbox/
  end

  test "index auto-resolves an email whose confirmation is already on a trip" do
    dup = InboundEmail.create!(message_id: "<dup@x>", subject: "Booking",
      body: "Confirmation: LIS4RT", received_at: Time.current, status: "received")
    get inbound_emails_path
    assert_equal "duplicate", dup.reload.status
    assert_equal trips(:lisbon), dup.trip
  end

  test "file attaches the email to a trip and removes it from the inbox" do
    inbound = inbound_emails(:pending_flight)
    assert_difference -> { trips(:lisbon).raw_emails.count }, 1 do
      post file_inbound_email_path(inbound), params: { trip_id: trips(:lisbon).id }
    end
    assert_equal "filed", inbound.reload.status
  end

  test "ignore dismisses the email" do
    post ignore_inbound_email_path(inbound_emails(:pending_hotel))
    assert_equal "ignored", inbound_emails(:pending_hotel).reload.status
  end
end
