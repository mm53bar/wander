require "test_helper"

class IntakeMailerTest < ActionMailer::TestCase
  setup do
    @inbound = inbound_emails(:pending_flight)
    @inbound.update!(from_address: "Mike <mike@example.com>", message_id: "orig@example.com",
                     references: "<older@example.com>", subject: "Fwd: Confirmation")
  end

  def notice(inbound = @inbound) = IntakeMailer.needs_manual_handling(inbound, "couldn't read it")

  test "threads the reply into the original conversation" do
    mail = notice
    assert_equal "<orig@example.com>", mail["In-Reply-To"].value
    assert_equal "<older@example.com> <orig@example.com>", mail["References"].value
    assert_equal "Re: Fwd: Confirmation", mail.subject
    assert_equal [ "mike@example.com" ], mail.to
  end

  test "sends unthreaded rather than forging a Message-ID the mail never had" do
    @inbound.update!(message_id: "imap-42", references: nil)
    mail = notice
    assert_nil mail["In-Reply-To"]
    assert_nil mail["References"]
    assert_equal [ "mike@example.com" ], mail.to
  end

  test "doesn't double up the Re: prefix" do
    @inbound.update!(subject: "Re: Confirmation")
    assert_equal "Re: Confirmation", notice.subject
  end

  test "body carries the reason and points at the inbox" do
    assert_match(/couldn't read it/, notice.body.to_s)
    assert_match(%r{/inbound_emails}, notice.body.to_s)
  end
end
