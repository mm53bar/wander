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
  # Notes are written in Markdown, parsed as GFM: people write "#### Heading"
  # straight after a list or another heading with no blank line between, which
  # kramdown's stricter default silently renders as literal text.
  #
  # Smart quotes are off on purpose — these notes are full of measurements
  # ("14' long", "6'7\" high") and curling those into ’ and ” is wrong.
  #
  # The HTML is sanitized even though there's no auth and only the household
  # writes it: it comes in from a form, and rendering form input raw is a habit
  # worth not forming.
  def markdown(text)
    return nil if text.blank?
    document = Kramdown::Document.new(
      text.to_s, input: "GFM", auto_ids: false,
      smart_quotes: %w[apos apos quot quot]
    )
    sanitize(document.to_html)
  end

  # Whether LLM-backed features (segment drafting) should be offered.
  def llm_available?
    @llm_available = LlmClient.from_env.configured? if @llm_available.nil?
    @llm_available
  end
end
