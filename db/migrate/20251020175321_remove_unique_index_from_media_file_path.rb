class RemoveUniqueIndexFromMediaFilePath < ActiveRecord::Migration[8.0]
  def change
    # Remove the unique index on file_path since multiple files can now be in the same directory
    remove_index :media, :file_path, if_exists: true
  end
end
