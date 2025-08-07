class CreatePhotos < ActiveRecord::Migration[8.0]
  def change
    create_table :photos do |t|
      t.string :title
      t.text :description
      t.string :file_path, null: false
      t.integer :file_size
      t.integer :width
      t.integer :height
      t.datetime :taken_at
      t.json :exif_data, default: {}
      t.string :thumbnail_path
      t.integer :thumbnail_width
      t.integer :thumbnail_height
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.references :user, null: false, foreign_key: true
      
      # Additional metadata fields
      t.string :original_filename
      t.string :content_type
      t.string :md5_hash # For duplicate detection
      t.float :latitude
      t.float :longitude
      t.string :camera_make
      t.string :camera_model

      t.timestamps
    end
    
    # Indexes for common queries (references already creates indexes for foreign keys)
    add_index :photos, :taken_at
    add_index :photos, :md5_hash, unique: true
    add_index :photos, [:latitude, :longitude]
    add_index :photos, :created_at
  end
end
