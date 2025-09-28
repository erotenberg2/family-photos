class AddFilesFailedToUploadLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :upload_logs, :files_failed, :integer, default: 0, null: false
    add_index :upload_logs, :files_failed
  end
end
