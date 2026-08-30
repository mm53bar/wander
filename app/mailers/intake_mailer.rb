# Replies into the thread of a booking email wander couldn't finish processing.
#
# Threading needs the ORIGINAL Message-ID, which is why intake reads raw RFC822
# rather than an envelope summary. When there is no real Message-ID the reply is
# sent unthreaded rather than carrying a forged one — a fabricated In-Reply-To
# threads with nothing and corrupts the recipient's view of the conversation.
class IntakeMailer < ApplicationMailer
  def self.configured? = ENV["SMTP_ADDRESS"].present?

  def needs_manual_handling(inbound, reason)
    @inbound = inbound
    @reason = reason
    @inbox_url = inbound_emails_url

    if inbound.threadable?
      headers["In-Reply-To"] = inbound.bracketed_message_id
      headers["References"] = inbound.reply_references
    end

    mail(to: AllowedSender.address_in(inbound.from_address), subject: reply_subject(inbound.subject))
  end

  private

  def reply_subject(subject)
    text = subject.to_s.presence || "your booking"
    text.match?(/\Are:/i) ? text : "Re: #{text}"
  end
end
