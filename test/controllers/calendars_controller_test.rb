require "test_helper"

class CalendarsControllerTest < ActionDispatch::IntegrationTest
  test "serves an iCalendar feed" do
    get calendar_path(format: :ics)
    assert_response :success
    assert_match %r{text/calendar}, response.media_type
    assert_includes response.body, "BEGIN:VCALENDAR"
    assert_includes response.body, "SUMMARY:✈️ EX204"
  end

  test "the subscribe link is a webcal URL ending in .ics" do
    get root_path
    assert_select "a[href=?]", "webcal://www.example.com/calendar.ics"
  end
end
