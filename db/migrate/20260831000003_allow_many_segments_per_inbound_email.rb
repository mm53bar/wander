class AllowManySegmentsPerInboundEmail < ActiveRecord::Migration[8.1]
  # One booking email routinely describes more than one segment — a return
  # ferry, a multi-leg flight, two confirmations in one forward. Triage used to
  # keep only the first.
  def up
    add_column :inbound_emails, :proposed_segments, :json
    add_column :inbound_emails, :created_segment_ids, :json, null: false, default: []

    select_all("SELECT id, proposed_segment, created_segment_id FROM inbound_emails").each do |row|
      segments = row["proposed_segment"].presence && "[#{row["proposed_segment"]}]"
      ids = row["created_segment_id"].present? ? "[#{row["created_segment_id"].to_i}]" : "[]"
      execute <<~SQL.squish
        UPDATE inbound_emails
           SET proposed_segments = #{quote(segments)}, created_segment_ids = #{quote(ids)}
         WHERE id = #{row["id"].to_i}
      SQL
    end

    remove_column :inbound_emails, :proposed_segment
    remove_column :inbound_emails, :created_segment_id
  end

  def down
    add_column :inbound_emails, :proposed_segment, :json
    add_column :inbound_emails, :created_segment_id, :integer

    select_all("SELECT id, proposed_segments, created_segment_ids FROM inbound_emails").each do |row|
      first_segment = JSON.parse(row["proposed_segments"].presence || "[]").first
      first_id = JSON.parse(row["created_segment_ids"].presence || "[]").first
      execute <<~SQL.squish
        UPDATE inbound_emails
           SET proposed_segment = #{quote(first_segment && first_segment.to_json)},
               created_segment_id = #{quote(first_id)}
         WHERE id = #{row["id"].to_i}
      SQL
    end

    remove_column :inbound_emails, :proposed_segments
    remove_column :inbound_emails, :created_segment_ids
  end
end
