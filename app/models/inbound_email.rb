# A message the email intake pulled from the shared inbox and its travel
# classifier flagged as travel-related. It sits in wander's own inbox until a
# human files it onto a trip (copying it into that trip's source emails) or
# ignores it as a false positive. Non-travel mail is never stored here — the
# intake leaves it untouched in the shared mailbox (see EmailIntakeJob).
class InboundEmail < ApplicationRecord
  belongs_to :trip, optional: true

  STATUSES = %w[received filed ignored duplicate].freeze

  validates :message_id, presence: true, uniqueness: true
  validates :received_at, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :received, -> { where(status: "received").order(received_at: :desc) }

  # File this onto a trip: copy it into that trip's source emails and mark it
  # handled. The intake's job is capture; turning it into segments stays a human
  # (or later, a parser) decision.
  # File as a source email on the trip (no segment). The InboundEmail itself is
  # the record; nothing is duplicated into raw_emails.
  def file_to!(trip)
    update!(trip: trip, status: "filed")
  end

  def ignore!
    update!(status: "ignored")
  end
  def email_text
    "#{subject}\n#{body}"
  end

  def duplicate_trip
    TripMatcher.new(email_text).duplicate_trip
  end

  def suggested_trip
    TripMatcher.new(email_text).suggested_trip
  end

  # Mark as an already-recorded duplicate of a trip we already have.
  def resolve_as_duplicate!(trip)
    update!(trip: trip, status: "duplicate")
  end
  def proposal?
    proposed_segment.present?
  end

  def proposed_trip
    Trip.find_by(id: proposed_trip_id)
  end

  # High-confidence assignment to an existing trip that fits within it — safe to
  # file without a human click (new-trip and extend cases stay for review).
  def auto_acceptable?
    confidence == "high" && proposed_trip_id.present? && !extends_trip && proposed_new_trip.blank?
  end

  # Store an LLM triage proposal on this email.
  def apply_proposal!(p)
    update!(
      proposed_segment: p[:segment], proposed_trip_id: p[:trip_id], proposed_new_trip: p[:new_trip],
      extends_trip: p[:extends_trip] || false, suggested_end_date: p[:suggested_end_date],
      confidence: p[:confidence], reason: p[:reason]
    )
  end

  # Materialize: create the segment on the target trip (creating a new trip or
  # extending the trip's end date when asked), and mark this email filed to it.
  def accept!(trip: nil, extend_dates: true)
    target = trip || proposed_trip || build_new_trip!
    raise ActiveRecord::RecordInvalid, self unless target

    segment = target.segments.create!(segment_attributes)
    if extend_dates && extends_trip && suggested_end_date && suggested_end_date > target.end_date
      target.update!(end_date: suggested_end_date)
    end
    update!(status: "filed", trip: target, created_segment_id: segment.id)
    segment
  end

  def auto_accept!
    accept!(trip: proposed_trip, extend_dates: false)
    update!(auto_filed: true)
  end

  # Reverse an auto-file: delete the created segment and return to the inbox.
  def undo_auto_file!
    Segment.where(id: created_segment_id).destroy_all if created_segment_id
    update!(status: "received", trip: nil, auto_filed: false, created_segment_id: nil)
  end

  private

  def build_new_trip!
    nt = proposed_new_trip
    return nil unless nt.is_a?(Hash) && nt["name"].present?
    seg_date = proposed_segment&.dig("starts_at")
    Trip.create!(
      name: nt["name"],
      start_date: nt["start_date"].presence || seg_date, end_date: nt["end_date"].presence || seg_date
    )
  end

  def segment_attributes
    s = proposed_segment || {}
    {
      kind: s["kind"].presence || "note", summary: s["summary"].presence || subject,
      starts_at: s["starts_at"].presence, ends_at: s["ends_at"].presence,
      starts_at_label: s["starts_at_label"].presence, ends_at_label: s["ends_at_label"].presence,
      location: s["location"].presence, confirmation: s["confirmation"].presence,
      links: Array(s["links"])
    }
  end
end
