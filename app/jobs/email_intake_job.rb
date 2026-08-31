# Reads the shared casey@ mailbox over IMAP, classifies each message, and
# captures the travel-related ones into wander's inbox (InboundEmail).
#
# Anything wander claims is moved out of the shared INBOX into its own folder,
# so what remains there is by definition not wander's. Capture happens BEFORE
# the move: if storing fails, the message stays put for the next run rather
# than disappearing from a mailbox other people read.
#
# Scheduled from config/recurring.yml. Dedup is by Message-ID, so a message that
# was already captured is moved out without being captured twice. Not configured
# (no IMAP env) → does nothing, keeping dev/CI quiet.
class EmailIntakeJob < ApplicationJob
  queue_as :default

  # llm: injectable so tests can drive the unreachable / unusable cases.
  def perform(mailbox: ImapMailbox.from_env, llm: LlmClient.from_env)
    return unless mailbox.configured?

    @llm = llm

    mailbox.open do |session|
      session.each_message { |message| handle(session, message) }
    end

    retry_awaiting_triage
  end

  private

  # Intake never re-reads a message it has already claimed, so a booking captured
  # while the LLM was unreachable would otherwise keep its empty proposal for
  # good. Picked up again here on each pass until triage works or the attempts
  # run out.
  def retry_awaiting_triage
    InboundEmail.awaiting_triage.each { |inbound| triage(inbound) }
  end

  # One bad message must not strand the rest of the batch behind it.
  def handle(session, message)
    return archive_known(session, message) if claimed?(message)

    result = TravelEmailClassifier.new(from: message.from, subject: message.subject, body: message.body).result
    return unless result.travel?

    inbound = capture(message, result)
    session.archive!(message)
    triage(inbound)
  rescue StandardError => e
    Rails.logger.error("EmailIntakeJob: uid=#{message.uid} #{e.class}: #{e.message}")
  end

  # Already in wander's inbox from an earlier run (or an earlier transport) —
  # still needs moving out of the shared mailbox.
  def claimed?(message)
    message.message_id.present? && InboundEmail.exists?(message_id: message.message_id)
  end

  def archive_known(session, message)
    session.archive!(message)
  end

  def capture(message, result)
    InboundEmail.create!(
      message_id: message.message_id.presence || "imap-#{message.uid}",
      references: message.references.join(" ").presence,
      from_address: message.from, subject: message.subject, body: message.body,
      received_at: message.received_at, score: result.score, signals: result.signals
    )
  end

  def triage(inbound)
    # 1) Deterministic: a booking already recorded (its confirmation is on a
    # segment) clears itself.
    if (dup = inbound.duplicate_trip)
      inbound.resolve_as_duplicate!(dup)
      return
    end

    # 2) LLM triage: propose the segment + where it belongs, and auto-file the
    # high-confidence existing-trip matches. New-trip and low-confidence ones
    # wait in the inbox for review.
    triager = TripTriager.new(inbound, client: @llm)
    return unless triager.available? # LLM switched off: the inbox is the review surface

    proposal = attempt_triage(inbound, triager)
    return if proposal.nil?

    inbound.apply_proposal!(proposal)
    return IntakeNotifier.new(inbound).undated! unless inbound.proposed_start_resolved?
    return unless inbound.auto_acceptable?

    begin
      inbound.auto_accept!
    rescue StandardError => e
      Rails.logger.error("EmailIntakeJob: auto-file failed for ##{inbound.id}: #{e.class}: #{e.message}")
      IntakeNotifier.new(inbound).failed!
    end
  end

  # Returns the proposal, or nil having counted the failure. A human only hears
  # about it once the retries are spent, so a brief LLM outage never produces a
  # "couldn't read this booking" notice for a booking that reads fine.
  def attempt_triage(inbound, triager)
    triager.triage.tap { |proposal| record_failed_triage(inbound) if proposal.nil? }
  rescue LlmClient::Unavailable => e
    Rails.logger.warn("EmailIntakeJob: triage unavailable for ##{inbound.id}: #{e.message}")
    record_failed_triage(inbound)
    nil
  end

  def record_failed_triage(inbound)
    inbound.record_triage_attempt!
    IntakeNotifier.new(inbound).unparseable! if inbound.triage_exhausted?
  end
end
