class AddCompletionStatusToUploadLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :upload_logs, :completion_status, :string, default: 'incomplete', null: false
    add_index :upload_logs, :completion_status
  end
end
