# Tells the sender, in their own email thread, that a booking wander captured
# needs handling by hand. Only fires for genuine dead ends — a low-confidence or
# new-trip proposal is a normal review state that's already visible in the
# Inbox, and mailing about those would train everyone to ignore the notices.
#
# Three gates, all of which must hold: the message hasn't been notified before,
# outbound mail is configured, and the sender is on the AllowedSender list.
class IntakeNotifier
  REASONS = {
    unparseable: "wander captured this booking but couldn't read an itinerary segment out of it.",
    undated: "wander read this booking but couldn't establish a time zone for it, so it has no " \
             "date on the calendar yet.",
    failed: "wander read this booking but couldn't file it."
  }.freeze

  # mailer: injectable so tests can use a hand-written fake instead of stubbing.
  def initialize(inbound, mailer: IntakeMailer)
    @inbound = inbound
    @mailer = mailer
  end

  def unparseable! = notify!(:unparseable)
  def undated! = notify!(:undated)
  def failed! = notify!(:failed)

  private

  def notify!(reason)
    return unless deliverable?

    @mailer.needs_manual_handling(@inbound, REASONS.fetch(reason)).deliver_later
    @inbound.update!(notified_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("IntakeNotifier: #{e.class}: #{e.message}")
  end

  def deliverable?
    @inbound.notified_at.blank? &&
      @mailer.configured? &&
      AllowedSender.allows?(@inbound.from_address)
  end
end
