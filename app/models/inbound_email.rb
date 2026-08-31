# A message the email intake pulled from the shared inbox and its travel
# classifier flagged as travel-related. It sits in wander's own inbox until a
# human files it onto a trip (copying it into that trip's source emails) or
# ignores it as a false positive. Non-travel mail is never stored here — the
# intake leaves it untouched in the shared mailbox (see EmailIntakeJob).
class InboundEmail < ApplicationRecord
  belongs_to :trip, optional: true

  STATUSES = %w[received filed ignored duplicate].freeze

  # Triage runs again on each intake pass until it works or the attempts run out.
  # Only then is a dead end reported to a human — a single failure is far more
  # often the LLM being briefly unreachable than a booking that can't be read.
  MAX_TRIAGE_ATTEMPTS = 3

  # Captured, but triage has never produced a proposal — the retry set.
  scope :awaiting_triage, lambda {
    where(status: "received", proposed_segments: nil)
      .where(triage_attempts: ...MAX_TRIAGE_ATTEMPTS)
  }

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
    segments_proposed.any?
  end

  # Always an array, whatever the column holds.
  def segments_proposed
    Array(proposed_segments).select { |s| s.is_a?(Hash) }
  end

  def record_triage_attempt!
    increment!(:triage_attempts)
  end

  def triage_exhausted?
    triage_attempts >= MAX_TRIAGE_ATTEMPTS
  end

  # False when the model read a time off the booking but no zone could be
  # established for it. A booking that states no time at all isn't a failure —
  # some genuinely have none. One unresolved segment holds the whole email back:
  # filing half a booking is more confusing than filing none of it.
  def proposed_start_resolved?
    segments_proposed.all? { |s| s["starts_at_local"].blank? || s["starts_at"].present? }
  end

  # Intake synthesises "imap-<uid>" when a message carries no Message-ID header.
  # That value must never reach In-Reply-To: it threads with nothing.
  def threadable?
    message_id.present? && !message_id.start_with?("imap-")
  end

  def bracketed_message_id
    "<#{message_id.delete_prefix("<").delete_suffix(">")}>"
  end

  def reply_references
    [ self[:references].presence, bracketed_message_id ].compact.join(" ")
  end

  def proposed_trip
    Trip.find_by(id: proposed_trip_id)
  end

  # High-confidence assignment to an existing trip — safe to file without a human
  # click. Extending that trip is allowed, but only when there's a date to extend
  # to at whichever edge it passes: without one the trip would end up not
  # containing the segment we just added. New-trip proposals stay for review.
  def auto_acceptable?
    return false unless confidence == "high" && proposed_trip_id.present? && proposed_new_trip.blank?
    !extends_trip || suggested_end_date.present? || suggested_start_date.present?
  end

  # Store an LLM triage proposal on this email.
  def apply_proposal!(p)
    update!(
      proposed_segments: p[:segments], proposed_trip_id: p[:trip_id], proposed_new_trip: p[:new_trip],
      extends_trip: p[:extends_trip] || false, suggested_start_date: p[:suggested_start_date],
      suggested_end_date: p[:suggested_end_date],
      confidence: p[:confidence], reason: p[:reason]
    )
  end

  # Materialize: create the segment on the target trip (creating a new trip or
  # extending the trip's end date when asked), and mark this email filed to it.
  def accept!(trip: nil, extend_dates: true)
    target = trip || proposed_trip || build_new_trip!
    raise ActiveRecord::RecordInvalid, self unless target

    created = segments_proposed.map { |s| target.segments.create!(segment_attributes(s)) }
    raise ActiveRecord::RecordInvalid, self if created.empty?

    moved = extend_dates && extends_trip ? widen!(target) : {}
    update!(status: "filed", trip: target, created_segment_ids: created.map(&:id),
            prior_trip_end_date: moved[:end_date], prior_trip_start_date: moved[:start_date])
    created
  end

  def auto_accept!
    accept!(trip: proposed_trip, extend_dates: true)
    update!(auto_filed: true)
  end

  # Reverse an auto-file: delete the created segment, put back either trip date
  # the extend moved, and return to the inbox.
  def undo_auto_file!
    Segment.where(id: created_segment_ids).destroy_all if created_segment_ids.present?
    restored = { end_date: prior_trip_end_date, start_date: prior_trip_start_date }.compact
    trip&.update!(restored) if restored.any?
    update!(status: "received", trip: nil, auto_filed: false, created_segment_ids: [],
            prior_trip_end_date: nil, prior_trip_start_date: nil)
  end

  private

  # Stretch the trip over a booking that runs past either edge, returning what
  # the dates were so undo can put them back.
  def widen!(trip)
    was = {}
    if suggested_end_date && suggested_end_date > trip.end_date
      was[:end_date] = trip.end_date
      trip.end_date = suggested_end_date
    end
    if suggested_start_date && suggested_start_date < trip.start_date
      was[:start_date] = trip.start_date
      trip.start_date = suggested_start_date
    end
    trip.save! if trip.changed?
    was
  end

  def build_new_trip!
    nt = proposed_new_trip
    return nil unless nt.is_a?(Hash) && nt["name"].present?
    seg_date = segments_proposed.first&.dig("starts_at")
    Trip.create!(
      name: nt["name"],
      start_date: nt["start_date"].presence || seg_date, end_date: nt["end_date"].presence || seg_date
    )
  end

  def segment_attributes(s)
    {
      kind: s["kind"].presence || "note", summary: s["summary"].presence || subject,
      starts_at: s["starts_at"].presence, ends_at: s["ends_at"].presence,
      starts_at_label: s["starts_at_label"].presence, ends_at_label: s["ends_at_label"].presence,
      location: s["location"].presence, confirmation: s["confirmation"].presence,
      links: Array(s["links"])
    }
  end
end
