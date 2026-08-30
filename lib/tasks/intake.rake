namespace :intake do
  desc "Show what the intake would capture and move, without writing anything"
  task preview: :environment do
    mailbox = ImapMailbox.from_env
    abort "IMAP is not configured (IMAP_HOST/IMAP_USERNAME/IMAP_PASSWORD)." unless mailbox.configured?

    capture, move, leave = [], [], []
    mailbox.open do |session|
      session.each_message do |message|
        row = "  %-38s %s" % [ (message.from.to_s[0, 38]), message.subject.to_s[0, 60] ]
        if message.message_id.present? && InboundEmail.exists?(message_id: message.message_id)
          move << row
        else
          result = TravelEmailClassifier.new(from: message.from, subject: message.subject, body: message.body).result
          (result.travel? ? capture : leave) << "#{row}  [score #{result.score}]"
        end
      end
    end

    puts "\nWOULD CAPTURE AND MOVE (#{capture.size}):"; puts capture
    puts "\nALREADY KNOWN — WOULD MOVE ONLY (#{move.size}):"; puts move
    puts "\nWOULD LEAVE IN INBOX (#{leave.size}):"; puts leave
    puts "\nNothing was written or moved."
  end
end
