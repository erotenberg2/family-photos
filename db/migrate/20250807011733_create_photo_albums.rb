class CreatePhotoAlbums < ActiveRecord::Migration[8.0]
  def change
    create_table :photo_albums do |t|
      t.references :photo, null: false, foreign_key: true
      t.references :album, null: false, foreign_key: true
      t.integer :position, null: false

      t.timestamps
    end
    
    # Ensure unique photo-album combinations and efficient position ordering
    add_index :photo_albums, [:photo_id, :album_id], unique: true
    add_index :photo_albums, [:album_id, :position]
  end
end
