class AddPreviewFieldsToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :preview_path, :string
    add_column :photos, :preview_width, :integer
    add_column :photos, :preview_height, :integer
  end
end
