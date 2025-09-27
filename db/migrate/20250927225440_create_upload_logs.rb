class CreateUploadLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :upload_logs do |t|
      t.references :user, null: false, foreign_key: true
      
      # Session/batch information
      t.datetime :session_started_at
      t.datetime :session_completed_at
      t.string :session_id
      t.string :batch_id, index: { unique: true }
      t.text :user_agent
      
      # Summary statistics
      t.integer :total_files_selected, default: 0
      t.integer :files_imported, default: 0
      t.integer :files_skipped, default: 0
      
      # Detailed file information in JSONB
      # Structure: [{ filename, file_size, content_type, status, skip_reason, medium_id, medium_type, mediable_id, mediable_type }, ...]
      t.jsonb :files_data, default: []
      
      t.timestamps
    end
    
    add_index :upload_logs, :files_data, using: :gin
  end
end
