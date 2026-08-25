module ApplicationHelper
  # The little calendar tile shown to the left of a segment. Empty (but
  # space-preserving) when the segment has no date.
  def date_badge(date)
    if date
      tag.div(class: "seg-date") do
        tag.span(date.day, class: "seg-date-day") +
          tag.span(date.strftime("%b"), class: "seg-date-month")
      end
    else
      tag.div("", class: "seg-date seg-date-empty")
    end
  end

  def trip_date_range(trip)
    "#{trip.start_date.iso8601} – #{trip.end_date.iso8601}"
  end
  # Whether LLM-backed features (segment drafting) should be offered.
  def llm_available?
    @llm_available = LlmClient.from_env.configured? if @llm_available.nil?
    @llm_available
  end
end
