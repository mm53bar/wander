namespace :intake do
  desc "Re-run triage and filing for stored emails from scratch: intake:reprocess[6,7]"
  task :reprocess, [ :ids ] => :environment do |_task, args|
    ids = args[:ids].to_s.split(/[,\s]+/).filter_map { |id| Integer(id, exception: false) }
    abort 'Usage: bin/rails "intake:reprocess[6]"' if ids.empty?

    InboundEmail.where(id: ids).order(:id).each do |email|
      # Only ever unpick wander's own work. An email filed by hand may have
      # segments a human wrote, which aren't ours to delete — and re-triaging it
      # would file a second copy alongside them.
      unless email.status == "received" || email.auto_filed?
        warn "##{email.id} was filed by hand — skipping, wander can't tell which segments are its own."
        next
      end

      if email.auto_filed?
        puts "##{email.id} undoing previous auto-file (segments #{email.created_segment_ids.join(', ')})"
        email.undo_auto_file!
      end

      # Same deterministic guard the intake runs: with our own segments now gone,
      # a confirmation still on a segment means it's recorded somewhere else.
      if (dup = email.duplicate_trip)
        email.resolve_as_duplicate!(dup)
        puts "##{email.id} already recorded on #{dup.name} — marked duplicate"
        next
      end

      triager = TripTriager.new(email)
      abort "The LLM isn't configured." unless triager.available?

      proposal = triager.triage
      if proposal.nil?
        puts "##{email.id} triage returned nothing — left in the inbox"
        next
      end

      email.apply_proposal!(proposal)
      unless email.proposed_start_resolved?
        puts "##{email.id} a segment has no resolvable time zone — left for review"
        next
      end

      puts "##{email.id} #{email.subject.to_s[0, 44]}"
      email.segments_proposed.each { |s| puts "    #{s['kind']} #{s['starts_at']} #{s['confirmation']}" }
      next puts("    → left in the inbox for review") unless email.auto_acceptable?

      created = email.auto_accept! && email.created_segment_ids
      puts "    → auto-filed to #{email.trip.name} as segment(s) #{created.join(', ')}"
    end
  end


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
