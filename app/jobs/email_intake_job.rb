# Reads the shared casey@ inbox through the Bichon archiver, classifies each
# recent message, and captures only travel-related ones into wander's inbox
# (InboundEmail). Everything else is left alone — Bichon is read-only and we
# store nothing for non-travel mail, so the shared mailbox is untouched.
#
# Scheduled from config/recurring.yml. Dedup is by Message-ID (InboundEmail),
# so overlapping look-back windows never double-capture. Not configured (no
# Bichon env) → does nothing, keeping dev/CI quiet.
class EmailIntakeJob < ApplicationJob
  queue_as :default

  LOOKBACK_DAYS = Integer(ENV.fetch("EMAIL_INTAKE_LOOKBACK_DAYS", 30))

  def perform(client: BichonClient.from_env, since: LOOKBACK_DAYS.days.ago)
    return unless client.configured?

    client.messages_since(since).each do |msg|
      next if InboundEmail.exists?(message_id: msg.message_id)

      # Cheap first pass on the envelope preview...
      next unless TravelEmailClassifier.new(from: msg.from, subject: msg.subject, body: msg.preview).result.travel?

      # ...then pull the full body (the preview is truncated and often omits the
      # reservation dates) for accurate storage, date-matching, and signals.
      body = client.content(msg.id, fallback: msg.preview)
      result = TravelEmailClassifier.new(from: msg.from, subject: msg.subject, body: body).result

      InboundEmail.create!(
        message_id: msg.message_id, from_address: msg.from, subject: msg.subject,
        body: body, received_at: msg.received_at, score: result.score, signals: result.signals
      )
    end
  end
end
