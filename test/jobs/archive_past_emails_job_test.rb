require "test_helper"

class ArchivePastEmailsJobTest < ActiveJob::TestCase
  test "perform archives emails for ended trips" do
    kept = raw_emails(:lisbon_confirmation).id
    gone = raw_emails(:kyoto_confirmation).id
    ArchivePastEmailsJob.perform_now
    assert RawEmail.exists?(kept)
    assert_not RawEmail.exists?(gone)
  end
end
