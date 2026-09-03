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

  test "folds content lines longer than 75 octets" do
    segments(:lisbon_flight).update!(emoji: "\u26F4\uFE0F", summary: "Sunshine Coast (Langdale) to Vancouver (Horseshoe Bay) ferry Queen of Surrey")
    ics = IcsCalendar.new(Segment.all).to_ics

    ics.split("\r\n").each { |line| assert line.bytesize <= 75, "line over 75 octets: #{line}" }
    unfolded = ics.gsub("\r\n ", "")
    assert_includes unfolded, "SUMMARY:\u26F4\uFE0F Sunshine Coast (Langdale) to Vancouver (Horseshoe Bay) ferry Queen of Surrey"
  end

  test "escapes commas and semicolons in text" do
    segments(:lisbon_flight).update!(location: "Gate 5, Terminal; A")
    ics = IcsCalendar.new(Segment.all).to_ics
    assert_includes ics, "LOCATION:Gate 5\\, Terminal\; A"
  end
end
