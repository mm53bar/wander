class Trip < ApplicationRecord
  has_many :segments, dependent: :destroy
  has_many :raw_emails, dependent: :destroy

  validates :name, presence: true
  validates :start_date, :end_date, presence: true
  validate :end_not_before_start

  # A trip is "past" once its last day is behind us; everything else is upcoming
  # (this includes trips happening right now). end_date is the pivot so a trip
  # stays on the Upcoming list until the day after it finishes.
  scope :upcoming, -> { where(end_date: Date.current..).order(:start_date) }
  scope :past, -> { where(end_date: ...Date.current).order(end_date: :desc) }

  def past?
    end_date < Date.current
  end

  # Segments in the order they happen: timed ones first by instant, then any
  # undated ones in the order they were added.
  def ordered_segments
    segments.order(Arel.sql("starts_at IS NULL, starts_at ASC, created_at ASC"))
  end

  private

  def end_not_before_start
    return if start_date.blank? || end_date.blank?
    errors.add(:end_date, "can't be before the start date") if end_date < start_date
  end
end
