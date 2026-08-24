class CalendarsController < ApplicationController
  # A subscribable iCalendar feed of every timed segment across all trips.
  # Point a calendar app at calendar_url(format: :ics) to keep it in sync.
  def show
    calendar = IcsCalendar.new(Segment.where.not(starts_at: nil).includes(:trip))
    send_data calendar.to_ics,
      type: "text/calendar; charset=utf-8",
      filename: "calendar.ics",
      disposition: "inline"
  end
end
