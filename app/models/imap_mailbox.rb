require "net/imap"
require "mail"

# Reads the shared casey@ mailbox over IMAP and files what wander claims into
# its own folder. Replaces the Bichon archiver hop — see
# docs/adr/20260829-imap-intake-direct-not-bichon.md.
#
# Two rules shape this, both because the mailbox is shared with other apps:
#   1. Messages are fetched with BODY.PEEK[] so wander never sets \Seen. Read
#      state belongs to whoever else is reading the inbox.
#   2. A message wander has claimed is MOVED to its own folder rather than
#      flagged, so nothing else has to keep stepping over it. Everything left in
#      INBOX is, by definition, not wander's.
#
# Config (env): IMAP_HOST, IMAP_PORT, IMAP_USERNAME, IMAP_PASSWORD,
# INTAKE_MAILBOX (default INBOX), INTAKE_ARCHIVE_MAILBOX (default Wander).
class ImapMailbox
  # message_id/references are the real RFC822 header values (bare, no angle
  # brackets) — the notice mailer threads its reply from them.
  Message = Data.define(:uid, :message_id, :references, :from, :subject, :body, :received_at)

  def self.from_env
    new(
      host: ENV["IMAP_HOST"], port: ENV.fetch("IMAP_PORT", 993).to_i,
      username: ENV["IMAP_USERNAME"], password: ENV["IMAP_PASSWORD"],
      source: ENV.fetch("INTAKE_MAILBOX", "INBOX"),
      archive: ENV.fetch("INTAKE_ARCHIVE_MAILBOX", "Wander")
    )
  end

  def initialize(host:, port:, username:, password:, source:, archive:)
    @host, @port, @username, @password = host, port, username, password
    @source, @archive = source, archive
  end

  def configured?
    @host.present? && @username.present? && @password.present?
  end

  # Opens one connection for the whole run and yields self. The archive folder
  # is created on demand so a fresh deploy doesn't need it made by hand.
  def open
    @imap = Net::IMAP.new(@host, port: @port, ssl: true)
    @imap.login(@username, @password)
    ensure_archive_mailbox
    @imap.select(@source)
    yield self
  ensure
    close
  end

  def each_message
    @imap.uid_search([ "ALL" ]).each do |uid|
      message = fetch(uid)
      yield message if message
    end
  end

  # Move a claimed message out of the shared inbox and into wander's folder.
  def archive!(message)
    if @imap.capability.include?("MOVE")
      @imap.uid_move(message.uid, @archive)
    else
      @imap.uid_copy(message.uid, @archive)
      @imap.uid_store(message.uid, "+FLAGS", [ :Deleted ])
      @imap.expunge
    end
  end

  private

  def close
    @imap&.logout
    @imap&.disconnect
  rescue StandardError
    nil
  ensure
    @imap = nil
  end

  def ensure_archive_mailbox
    @imap.create(@archive) if @imap.list("", @archive).blank?
  rescue Net::IMAP::NoResponseError
    nil # Already exists (servers differ on whether LIST or CREATE is authoritative).
  end

  # BODY.PEEK[] — the plain BODY[] fetch would set \Seen on a shared mailbox.
  def fetch(uid)
    raw = @imap.uid_fetch(uid, "BODY.PEEK[]")&.first&.attr&.dig("BODY[]")
    return nil if raw.blank?
    build(uid, Mail.read_from_string(raw))
  rescue StandardError => e
    Rails.logger.error("ImapMailbox: could not read uid=#{uid}: #{e.class}: #{e.message}")
    nil
  end

  def build(uid, mail)
    Message.new(
      uid: uid,
      message_id: mail.message_id.presence,
      references: Array(mail.references).compact,
      from: mail[:from].to_s.presence || mail.from&.first.to_s,
      subject: mail.subject.to_s,
      body: body_text(mail),
      received_at: mail.date&.to_time || Time.current
    )
  end

  # Prefer the plain-text part; fall back to the HTML with tags stripped.
  def body_text(mail)
    part = mail.multipart? ? (mail.text_part || mail.html_part) : mail
    return "" unless part
    text = part.decoded.to_s
    html?(part) ? strip_html(text) : text
  rescue StandardError
    ""
  end

  def html?(part)
    part.content_type.to_s.include?("text/html")
  end

  def strip_html(html)
    ActionView::Base.full_sanitizer.sanitize(html).to_s.squish
  end
end
