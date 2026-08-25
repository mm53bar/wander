class Trip < ApplicationRecord
  has_many :segments, dependent: :destroy
  has_many :raw_emails, dependent: :destroy
  has_many :inbound_emails, dependent: :nullify

  validates :name, presence: true
  validates :start_date, :end_date, presence: true
  validate :end_not_before_start

  # A trip is "past" once its last day is behind us; everything else is upcoming
  # (this includes trips happening right now). end_date is the pivot so a trip
  # stays on the Upcoming list until the day after it finishes.
  scope :unarchived, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil).order(end_date: :desc) }
  # Active (unarchived) trips split by whether they've finished.
  scope :upcoming, -> { unarchived.where(end_date: Date.current..).order(:start_date) }
  scope :past, -> { unarchived.where(end_date: ...Date.current).order(end_date: :desc) }
  # Trips offered when filing a booking: upcoming, unarchived, soonest first.
  scope :fileable, -> { upcoming }

  def past?
    end_date < Date.current
  end

  def archived?
    archived_at.present?
  end

  def archive! = update!(archived_at: Time.current)
  def unarchive! = update!(archived_at: nil)

  # "Trip name — Sep 5–8, 2026" for pickers.
  def label_with_dates
    same_year = start_date.year == end_date.year
    left = start_date.strftime("%b %-d")
    right = same_year ? end_date.strftime("%b %-d, %Y") : end_date.strftime("%b %-d, %Y")
    "#{name} — #{left}–#{right}"
  end

  # Segments in the order they happen: timed ones first by instant, then any
  # undated ones in the order they were added.
  # Migrated/manual source emails plus filed inbound ones, as one list.
  def source_emails
    all = raw_emails.to_a + inbound_emails.where(status: %w[filed duplicate]).to_a
    # De-dupe a legacy email that exists as both a raw_email and a filed inbound.
    all.uniq { |e| [ e.subject, e.received_at&.to_i ] }
       .sort_by { |e| e.received_at || Time.zone.at(0) }
  end

  def ordered_segments
    segments.order(Arel.sql("starts_at IS NULL, starts_at ASC, created_at ASC"))
  end

  private

  def end_not_before_start
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "can't be before the start date") if end_date < start_date
  end
end
