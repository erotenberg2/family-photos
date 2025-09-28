class AddDimensionsToPhotos < ActiveRecord::Migration[8.0]
  def change
    add_column :photos, :width, :integer
    add_column :photos, :height, :integer
    
    add_index :photos, :width
    add_index :photos, :height
  end
end
