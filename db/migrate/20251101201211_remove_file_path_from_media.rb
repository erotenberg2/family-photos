class RemoveFilePathFromMedia < ActiveRecord::Migration[8.0]
  def change
    remove_column :media, :file_path, :string
  end
end
