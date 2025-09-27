class AddTimingFieldsToMedium < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :upload_started_at, :datetime
    add_column :media, :upload_completed_at, :datetime
    add_column :media, :processing_started_at, :datetime
    add_column :media, :processing_completed_at, :datetime
    add_column :media, :upload_session_id, :string
    add_column :media, :upload_batch_id, :string
  end
end
