require "test_helper"

class IntakeNotifierTest < ActiveSupport::TestCase
  # Hand-written stand-in for IntakeMailer, recording what it was asked to send.
  class FakeMailer
    class Delivery
      def deliver_later = FakeMailer.delivered << true
    end

    def self.sent = @sent ||= []
    def self.delivered = @delivered ||= []
    def self.configured? = @configured

    def self.configured=(value)
      @configured = value
    end

    def self.reset!
      @sent = []
      @delivered = []
      @configured = true
    end

    def self.needs_manual_handling(inbound, reason)
      sent << [ inbound.id, reason ]
      Delivery.new
    end
  end

  setup do
    FakeMailer.reset!
    @inbound = inbound_emails(:pending_flight)
    @inbound.update!(from_address: "Mike <mike@example.com>", message_id: "orig@example.com",
                     references: "<older@example.com>")
    AllowedSender.create!(address: "mike@example.com")
  end

  def notifier(inbound = @inbound) = IntakeNotifier.new(inbound, mailer: FakeMailer)

  test "replies to an allow-listed sender and records that it did" do
    notifier.unparseable!
    assert_equal 1, FakeMailer.sent.size
    assert_equal 1, FakeMailer.delivered.size
    assert_match(/couldn't read an itinerary segment/, FakeMailer.sent.first.last)
    assert @inbound.reload.notified_at
  end

  test "never notifies twice about the same message" do
    notifier.unparseable!
    notifier(@inbound.reload).undated!
    assert_equal 1, FakeMailer.sent.size
  end

  test "stays silent for a sender that isn't on the list" do
    @inbound.update!(from_address: "confirmations@camis.com")
    notifier.unparseable!
    assert_empty FakeMailer.sent
    assert_nil @inbound.reload.notified_at
  end

  test "stays silent when outbound mail isn't configured" do
    FakeMailer.configured = false
    notifier.unparseable!
    assert_empty FakeMailer.sent
    assert_nil @inbound.reload.notified_at
  end
end
