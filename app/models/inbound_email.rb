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
  def file_to!(trip)
    transaction do
      trip.raw_emails.create!(
        from_address: from_address, subject: subject, body: body, received_at: received_at
      )
      update!(trip: trip, status: "filed")
    end
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
end
