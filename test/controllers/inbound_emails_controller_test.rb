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

  test "file marks the email filed to a trip (source record, no segment)" do
    inbound = inbound_emails(:pending_flight)
    post file_inbound_email_path(inbound), params: { trip_id: trips(:lisbon).id }
    assert_equal "filed", inbound.reload.status
    assert_equal trips(:lisbon), inbound.trip
  end

  test "accept materializes every segment in the proposal" do
    inbound = inbound_emails(:pending_flight)
    inbound.apply_proposal!(
      segments: [ { "kind" => "ferry", "summary" => "Outbound" }, { "kind" => "ferry", "summary" => "Return" } ],
      trip_id: trips(:lisbon).id, new_trip: nil, extends_trip: false, suggested_end_date: nil,
      confidence: "high", reason: nil
    )
    assert_difference -> { trips(:lisbon).segments.count }, 2 do
      post accept_inbound_email_path(inbound)
    end
    assert_equal 2, inbound.reload.created_segment_ids.size
  end

  test "accept materializes a proposal into a segment on the trip" do
    inbound = inbound_emails(:pending_hotel)
    inbound.apply_proposal!(segments: [ { "kind" => "hotel", "summary" => "Stay" } ], trip_id: trips(:lisbon).id,
      new_trip: nil, extends_trip: false, suggested_end_date: nil, confidence: "high", reason: nil)
    assert_difference -> { trips(:lisbon).segments.count }, 1 do
      post accept_inbound_email_path(inbound)
    end
    assert_redirected_to trips(:lisbon)
    assert_equal "filed", inbound.reload.status
  end

  test "undo returns an auto-filed email to the inbox" do
    inbound = inbound_emails(:pending_hotel)
    inbound.apply_proposal!(segments: [ { "kind" => "hotel", "summary" => "Stay" } ], trip_id: trips(:lisbon).id,
      new_trip: nil, extends_trip: false, suggested_end_date: nil, confidence: "high", reason: nil)
    inbound.auto_accept!
    post undo_inbound_email_path(inbound)
    assert_equal "received", inbound.reload.status
  end

  test "ignore dismisses the email" do
    post ignore_inbound_email_path(inbound_emails(:pending_hotel))
    assert_equal "ignored", inbound_emails(:pending_hotel).reload.status
  end

  test "destroy removes the captured email" do
    assert_difference -> { InboundEmail.count }, -1 do
      delete inbound_email_path(inbound_emails(:pending_hotel))
    end
  end
end
