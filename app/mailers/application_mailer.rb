class ApplicationMailer < ActionMailer::Base
  # Must be a domain the SMTP relay is allowed to send as — set MAILER_FROM_ADDRESS.
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "wander@example.com")
  layout "mailer"
end
