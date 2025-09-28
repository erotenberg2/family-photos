class AddClientFilePathToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :client_file_path, :text
  end
end
