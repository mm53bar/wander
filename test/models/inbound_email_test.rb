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
             trip_id: trips(:lisbon).id, new_trip: nil, extends_trip: false,
             suggested_start_date: nil, suggested_end_date: nil, confidence: "high", reason: "x" }
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

  test "auto_acceptable? only for high-confidence against an existing trip" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound)
    assert inbound.auto_acceptable?
    propose(inbound, confidence: "medium")
    assert_not inbound.auto_acceptable?
    propose(inbound, trip_id: nil, new_trip: { "name" => "X", "start_date" => "2027-01-01", "end_date" => "2027-01-02" })
    assert_not inbound.auto_acceptable?
  end

  test "auto_acceptable? allows an extend, but only with an end date to extend to" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_end_date: (trips(:lisbon).end_date + 2).to_s)
    assert inbound.auto_acceptable?
    propose(inbound, extends_trip: true, suggested_end_date: nil)
    assert_not inbound.auto_acceptable?
  end

  test "auto_accept! extends the trip so it can't end before its own last segment" do
    new_end = trips(:lisbon).end_date + 2
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_end_date: new_end.to_s)
    inbound.auto_accept!
    assert_equal new_end, trips(:lisbon).reload.end_date
    assert inbound.reload.auto_filed
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

  test "undo_auto_file! puts back a trip end date the extend moved" do
    original_end = trips(:lisbon).end_date
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_end_date: (original_end + 2).to_s)
    inbound.auto_accept!
    assert_equal original_end + 2, trips(:lisbon).reload.end_date

    inbound.undo_auto_file!
    assert_equal original_end, trips(:lisbon).reload.end_date
    assert_nil inbound.reload.prior_trip_end_date
  end

  test "accept! widens a trip backwards when the booking starts before it" do
    original_start = trips(:lisbon).start_date
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_start_date: (original_start - 2).to_s)
    inbound.accept!(extend_dates: true)
    assert_equal original_start - 2, trips(:lisbon).reload.start_date
  end

  test "auto_acceptable? accepts an extend backed by a start date alone" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_start_date: (trips(:lisbon).start_date - 1).to_s)
    assert inbound.auto_acceptable?
  end

  test "undo_auto_file! puts back a start date the extend moved" do
    original_start = trips(:lisbon).start_date
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_start_date: (original_start - 2).to_s)
    inbound.auto_accept!
    assert_equal original_start - 2, trips(:lisbon).reload.start_date

    inbound.undo_auto_file!
    assert_equal original_start, trips(:lisbon).reload.start_date
    assert_nil inbound.reload.prior_trip_start_date
  end

  test "widening never narrows a trip that already covers the booking" do
    trip = trips(:lisbon)
    original = [ trip.start_date, trip.end_date ]
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true,
            suggested_start_date: (trip.start_date + 1).to_s, suggested_end_date: (trip.end_date - 1).to_s)
    inbound.accept!(extend_dates: true)
    assert_equal original, [ trips(:lisbon).reload.start_date, trips(:lisbon).end_date ]
  end
end
