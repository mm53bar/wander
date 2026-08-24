require "test_helper"

class RawEmailTest < ActiveSupport::TestCase
  test "archive_past! removes emails for ended trips only" do
    kept = raw_emails(:lisbon_confirmation).id
    gone = raw_emails(:kyoto_confirmation).id
    assert_difference -> { RawEmail.count }, -1 do
      RawEmail.archive_past!
    end
    assert RawEmail.exists?(kept)
    assert_not RawEmail.exists?(gone)
  end

  test "received_at defaults to now" do
    email = trips(:lisbon).raw_emails.create!(subject: "Hi", body: "there")
    assert_not_nil email.received_at
  end
end
