# Discards the source emails stored against trips that have already ended, so
# the app never accumulates a mailbox. Scheduled daily in config/recurring.yml;
# the index action also calls RawEmail.archive_past! as a backstop.
class ArchivePastEmailsJob < ApplicationJob
  queue_as :default

  def perform
    RawEmail.archive_past!
  end
end
