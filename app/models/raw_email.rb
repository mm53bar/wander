class RawEmail < ApplicationRecord
  belongs_to :trip

  validates :subject, :body, presence: true
  validates :received_at, presence: true

  before_validation { self.received_at ||= Time.current }

  # Source emails are kept only while a trip is current, then discarded so the
  # app doesn't accumulate a mailbox. Run daily by ArchivePastEmailsJob.
  def self.archive_past!(as_of: Date.current)
    joins(:trip).where(trips: { end_date: ...as_of }).delete_all
  end
end
