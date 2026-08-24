require "test_helper"

class IcsCalendarTest < ActiveSupport::TestCase
  test "emits a VEVENT for a timed segment and skips undated ones" do
    ics = IcsCalendar.new(Segment.all).to_ics
    assert_includes ics, "BEGIN:VCALENDAR"
    assert_includes ics, "UID:segment-#{segments(:lisbon_flight).id}@wander"
    assert_not_includes ics, "UID:segment-#{segments(:lisbon_hotel).id}@wander"
  end

  test "uses CRLF line endings" do
    assert_includes IcsCalendar.new(Segment.all).to_ics, "\r\n"
  end

  test "escapes commas and semicolons in text" do
    segments(:lisbon_flight).update!(location: "Gate 5, Terminal; A")
    ics = IcsCalendar.new(Segment.all).to_ics
    assert_includes ics, "LOCATION:Gate 5\\, Terminal\; A"
  end
end
