class AddCurrentFilenameToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :current_filename, :string, null: false
    add_index :media, :current_filename
  end
end
