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
    base = { segments: [ { "kind" => "flight", "summary" => "Test flight", "starts_at" => "#{trips(:lisbon).start_date + 1}T10:00:00Z", "confirmation" => "ZZ9" } ],
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
    assert_equal "flight", Segment.find(inbound.created_segment_ids.first).kind
  end

  test "accept! creates a new trip from the proposal" do
    inbound = inbound_emails(:pending_hotel)
    propose(inbound, trip_id: nil, new_trip: { "name" => "Spring Trip", "start_date" => "2027-03-01", "end_date" => "2027-03-05" }, confidence: "medium")
    assert_difference -> { Trip.count }, 1 do
      created = inbound.accept!
      assert_equal "Spring Trip", created.first.trip.name
    end
  end

  test "accept! carries the booking's travellers onto a new trip" do
    inbound = inbound_emails(:pending_hotel)
    propose(inbound, trip_id: nil, confidence: "medium",
                     new_trip: { "name" => "Spring Trip", "start_date" => "2027-03-01", "end_date" => "2027-03-05", "travellers" => "Avery Example" })
    assert_equal "Avery Example", inbound.accept!.first.trip.travellers
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

  test "auto_acceptable? when flagged as an extend but every date is on the trip's edges" do
    trip = trips(:lisbon)
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_start_date: trip.start_date.to_s, suggested_end_date: trip.end_date.to_s,
                     segments: [ { "kind" => "flight", "starts_at" => "#{trip.start_date}T15:00:00Z" },
                                 { "kind" => "flight", "starts_at" => "#{trip.end_date}T18:00:00Z" } ])
    assert inbound.auto_acceptable?
  end

  test "auto_acceptable? not when a segment falls outside the trip, flagged or not" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound, segments: [ { "kind" => "flight", "starts_at" => "#{trips(:lisbon).end_date + 1}T18:00:00Z" } ])
    assert_not inbound.auto_acceptable?
  end

  test "auto_acceptable? not for an extend with no dates to check" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, segments: [ { "kind" => "note", "summary" => "Undated" } ])
    assert_not inbound.auto_acceptable?
  end

  test "auto_acceptable? never for an extend, at either edge" do
    inbound = inbound_emails(:pending_flight)
    propose(inbound, extends_trip: true, suggested_end_date: (trips(:lisbon).end_date + 2).to_s)
    assert_not inbound.auto_acceptable?
    propose(inbound, extends_trip: true, suggested_start_date: (trips(:lisbon).start_date - 1).to_s)
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
    seg_ids = inbound.created_segment_ids
    inbound.undo_auto_file!
    assert_empty Segment.where(id: seg_ids)
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
