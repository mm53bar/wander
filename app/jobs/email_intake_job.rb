# Reads the shared casey@ mailbox over IMAP, classifies each message, and
# captures the travel-related ones into wander's inbox (InboundEmail).
#
# Other apps read the same mailbox, so wander only moves a message out of INBOX
# into its own folder once it is sure the message is its own: triage (the LLM)
# has read it as a booking, it repeats a recorded booking, or a human filed it.
# A message triage says isn't a booking is released and never touched again. The
# classifier alone decides only when no LLM is configured. Capture happens BEFORE
# any move, so a failed save leaves the message where it was.
#
# Scheduled from config/recurring.yml. Dedup is by Message-ID, so a message seen
# on an earlier run is picked up where it left off rather than captured twice.
# Not configured (no IMAP env) → does nothing, keeping dev/CI quiet.
class EmailIntakeJob < ApplicationJob
  queue_as :default

  # llm: injectable so tests can drive the unreachable / unusable cases.
  def perform(mailbox: ImapMailbox.from_env, llm: LlmClient.from_env)
    return unless mailbox.configured?

    @llm = llm
    @seen = []

    mailbox.open do |session|
      session.each_message { |message| handle(session, message) }
    end

    retry_awaiting_triage
  end

  private

  # Rows whose message wasn't in INBOX this pass (moved before this job waited
  # for triage) still need their proposal; those that were got it in handle.
  def retry_awaiting_triage
    InboundEmail.awaiting_triage.where.not(id: @seen).each { |inbound| triage(inbound) }
  end

  # One bad message must not strand the rest of the batch behind it.
  def handle(session, message)
    inbound = InboundEmail.find_by(message_id: intake_id(message))
    if inbound.nil?
      result = TravelEmailClassifier.new(from: message.from, subject: message.subject, body: message.body).result
      return unless result.travel?

      inbound = capture(message, result)
    end
    @seen << inbound.id

    triage(inbound) if inbound.awaiting_triage?
    session.archive!(message) if claim?(inbound)
  rescue StandardError => e
    Rails.logger.error("EmailIntakeJob: uid=#{message.uid} #{e.class}: #{e.message}")
  end

  # A message with no Message-ID header is keyed by UID, so a later pass still
  # recognises it (and a released one stays released).
  def intake_id(message)
    message.message_id.presence || "imap-#{message.uid}"
  end

  def claim?(inbound)
    inbound.claimable? || (!@llm.configured? && inbound.status == "received")
  end

  def capture(message, result)
    InboundEmail.create!(
      message_id: intake_id(message),
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
    return inbound.release! unless proposal[:travel]

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

  # Returns the proposal, or nil. Only an unusable answer counts toward giving
  # up; an outage of any length leaves the email queued, so it never produces a
  # "couldn't read this booking" notice for a booking that reads fine.
  def attempt_triage(inbound, triager)
    triager.triage.tap { |proposal| record_failed_triage(inbound) if proposal.nil? }
  rescue LlmClient::Unavailable => e
    Rails.logger.warn("EmailIntakeJob: triage unavailable for ##{inbound.id}: #{e.message}")
    nil
  end

  def record_failed_triage(inbound)
    inbound.record_triage_attempt!
    IntakeNotifier.new(inbound).unparseable! if inbound.triage_exhausted?
  end
end
