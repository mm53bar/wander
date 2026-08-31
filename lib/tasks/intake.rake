namespace :intake do
  desc "Re-run triage on everything waiting in the inbox (after the triager changes)"
  task retriage: :environment do
    emails = InboundEmail.received.to_a
    abort "Nothing waiting in the inbox." if emails.empty?

    emails.each do |email|
      triager = TripTriager.new(email)
      abort "The LLM isn't configured." unless triager.available?

      before = email.proposed_trip_id ? "trip #{email.proposed_trip_id}" : email.proposed_new_trip&.dig("name").inspect
      proposal = triager.triage
      if proposal.nil?
        puts "##{email.id} #{email.subject.to_s[0, 40]}: triage returned nothing, left as-is"
        next
      end

      email.apply_proposal!(proposal)
      after = email.proposed_trip_id ? "trip #{email.proposed_trip_id}" : email.proposed_new_trip&.dig("name").inspect
      filed = email.auto_acceptable? ? (email.auto_accept! && " → auto-filed") : ""
      puts "##{email.id} #{email.subject.to_s[0, 40]}: #{before} → #{after}" \
           " (#{email.confidence}#{email.extends_trip ? ", extends to #{email.suggested_end_date}" : ""})#{filed}"
      puts "    starts_at #{email.proposed_segment['starts_at'].inspect}"
    end
  end


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
