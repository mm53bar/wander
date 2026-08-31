require "test_helper"

class EmailIntakeJobTest < ActiveJob::TestCase
  # Stand-in for ImapMailbox (no network), recording what got moved out.
  class FakeMailbox
    attr_reader :archived

    def initialize(messages)
      @messages = messages
      @archived = []
    end

    def configured? = true
    def open = yield self
    def each_message(&block) = @messages.each(&block)
    def archive!(message) = @archived << message.message_id
  end

  def msg(message_id, from:, subject:, body:, uid: 1)
    ImapMailbox::Message.new(
      uid: uid, message_id: message_id, references: [], from: from,
      subject: subject, body: body, received_at: Time.current
    )
  end

  test "captures only travel-related messages" do
    mailbox = FakeMailbox.new([
      msg("t1@x", from: "no-reply@bcferries.com", subject: "Your booking is confirmed", body: "Your ferry itinerary."),
      msg("n1@x", from: "support@fastmail.com", subject: "Welcome", body: "Explore your mailbox.", uid: 2)
    ])
    assert_difference -> { InboundEmail.count }, 1 do
      EmailIntakeJob.perform_now(mailbox: mailbox)
    end
    assert InboundEmail.exists?(message_id: "t1@x")
    assert_not InboundEmail.exists?(message_id: "n1@x")
  end

  test "moves what it claims out of the shared inbox, and leaves the rest" do
    mailbox = FakeMailbox.new([
      msg("t1@x", from: "no-reply@bcferries.com", subject: "Your booking is confirmed", body: "Your ferry itinerary."),
      msg("n1@x", from: "support@fastmail.com", subject: "Welcome", body: "Explore your mailbox.", uid: 2)
    ])
    EmailIntakeJob.perform_now(mailbox: mailbox)
    assert_equal [ "t1@x" ], mailbox.archived
  end

  test "moves an already-captured message out without capturing it twice" do
    existing = inbound_emails(:pending_flight)
    mailbox = FakeMailbox.new([ msg(existing.message_id, from: existing.from_address, subject: existing.subject, body: existing.body) ])
    assert_no_difference -> { InboundEmail.count } do
      EmailIntakeJob.perform_now(mailbox: mailbox)
    end
    assert_equal [ existing.message_id ], mailbox.archived
  end

  test "is idempotent across runs (dedup by message_id)" do
    mailbox = FakeMailbox.new([ msg("t1@x", from: "no-reply@bcferries.com", subject: "Booking confirmation", body: "Your itinerary and booking reference.") ])
    EmailIntakeJob.perform_now(mailbox: mailbox)
    assert_no_difference -> { InboundEmail.count } do
      EmailIntakeJob.perform_now(mailbox: mailbox)
    end
  end

  class ExplodingMessage
    def uid = 1
    def message_id = "bad@x"
    def from = "no-reply@bcferries.com"
    def subject = "Booking confirmation"
    def body = raise("unreadable")
  end

  test "one unreadable message doesn't strand the rest of the batch" do
    good = msg("t2@x", from: "no-reply@bcferries.com", subject: "Booking confirmation", body: "Your itinerary and booking reference.", uid: 2)

    EmailIntakeJob.perform_now(mailbox: FakeMailbox.new([ ExplodingMessage.new, good ]))
    assert InboundEmail.exists?(message_id: "t2@x")
    assert_not InboundEmail.exists?(message_id: "bad@x")
  end

  test "does nothing when the mailbox is not configured" do
    unconfigured = Class.new { def configured? = false }.new
    assert_no_difference -> { InboundEmail.count } do
      EmailIntakeJob.perform_now(mailbox: unconfigured)
    end
  end

  # LLM stand-ins: one that's briefly unreachable, one that answers unusably.
  class UnavailableLlm
    def configured? = true
    def complete_json(**) = raise(LlmClient::Unavailable, "Net::ReadTimeout")
  end

  class UselessLlm
    def configured? = true
    def complete_json(**) = nil
  end

  def travel_message(id = "t9@x")
    msg(id, from: "no-reply@bcferries.com", subject: "Booking confirmation",
        body: "Your itinerary and booking reference.")
  end

  test "a brief LLM outage doesn't notify, and leaves the booking to be retried" do
    inbound = inbound_emails(:pending_flight)
    inbound.update!(proposed_segment: nil, triage_attempts: 0)
    AllowedSender.create!(address: AllowedSender.address_in(inbound.from_address))

    EmailIntakeJob.perform_now(mailbox: FakeMailbox.new([]), llm: UnavailableLlm.new)

    assert_equal 1, inbound.reload.triage_attempts
    assert_nil inbound.notified_at, "should not report a dead end on the first failure"
    assert_includes InboundEmail.awaiting_triage, inbound, "should still be queued for retry"
  end

  test "gives up and reports only once the retries are spent" do
    inbound = inbound_emails(:pending_flight)
    inbound.update!(proposed_segment: nil, triage_attempts: InboundEmail::MAX_TRIAGE_ATTEMPTS - 1)

    EmailIntakeJob.perform_now(mailbox: FakeMailbox.new([]), llm: UselessLlm.new)

    inbound.reload
    assert_equal InboundEmail::MAX_TRIAGE_ATTEMPTS, inbound.triage_attempts
    assert_not_includes InboundEmail.awaiting_triage, inbound, "exhausted, stop retrying"
  end
end
