require "test_helper"

class InboundEmailTest < ActiveSupport::TestCase
  test "file_to! marks the email filed to the trip as a source record" do
    inbound = inbound_emails(:pending_flight)
    inbound.file_to!(trips(:lisbon))
    assert_equal "filed", inbound.reload.status
    assert_equal trips(:lisbon), inbound.trip
    assert_includes trips(:lisbon).source_emails, inbound
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
  def propose(inbound, **over)
    base = { segment: { "kind" => "flight", "summary" => "Test flight", "starts_at" => "2026-09-06T10:00:00", "confirmation" => "ZZ9" },
             trip_id: trips(:lisbon).id, new_trip: nil, extends_trip: false, suggested_end_date: nil, confidence: "high", reason: "x" }
    inbound.apply_proposal!(base.merge(over))
  end

  test "accept! creates a segment on the proposed trip and files the email" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound)
    assert_difference -> { trips(:lisbon).segments.count }, 1 do
      inbound.accept!
    end
    assert_equal "filed", inbound.reload.status
    assert_equal "flight", Segment.find(inbound.created_segment_id).kind
  end

  test "accept! creates a new trip from the proposal" do
    inbound = inbound_emails(:pending_hotel)
    propose(inbound, trip_id: nil, new_trip: { "name" => "Spring Trip", "start_date" => "2027-03-01", "end_date" => "2027-03-05" }, confidence: "medium")
    assert_difference -> { Trip.count }, 1 do
      seg = inbound.accept!
      assert_equal "Spring Trip", seg.trip.name
    end
  end

  test "accept! extends the trip end date when asked" do
    new_end = trips(:lisbon).end_date + 3
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_end_date: new_end.to_s)
    inbound.accept!(extend_dates: true)
    assert_equal new_end, trips(:lisbon).reload.end_date
  end

  test "auto_acceptable? only for high-confidence within an existing trip" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound)
    assert inbound.auto_acceptable?
    propose(inbound, extends_trip: true)
    assert_not inbound.auto_acceptable?
    propose(inbound, trip_id: nil, new_trip: { "name" => "X", "start_date" => "2027-01-01", "end_date" => "2027-01-02" })
    assert_not inbound.auto_acceptable?
  end

  test "undo_auto_file! deletes the segment and returns to the inbox" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound)
    inbound.auto_accept!
    seg_id = inbound.created_segment_id
    inbound.undo_auto_file!
    assert_not Segment.exists?(seg_id)
    assert_equal "received", inbound.reload.status
  end
end
