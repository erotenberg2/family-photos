class RefactorPhotosForMediumStructure < ActiveRecord::Migration[8.0]
  def up
    # Add medium reference to photos table
    add_reference :photos, :medium, null: true, foreign_key: true
    
    # Remove columns that will now be in the media table
    remove_column :photos, :file_path, :string
    remove_column :photos, :file_size, :integer  
    remove_column :photos, :original_filename, :string
    remove_column :photos, :content_type, :string
    remove_column :photos, :md5_hash, :string
    remove_column :photos, :width, :integer
    remove_column :photos, :height, :integer
    remove_column :photos, :taken_at, :datetime
    remove_column :photos, :uploaded_by_id, :bigint
    remove_column :photos, :user_id, :bigint
    
    # Keep photo-specific columns:
    # - title (already exists)
    # - description (already exists) 
    # - exif_data (already exists)
    # - thumbnail_path (already exists)
    # - thumbnail_width (already exists)
    # - thumbnail_height (already exists)
    # - latitude (already exists)
    # - longitude (already exists)
    # - camera_make (already exists)
    # - camera_model (already exists)
    
    # Remove indexes that are no longer relevant
    remove_index :photos, :md5_hash if index_exists?(:photos, :md5_hash)
    remove_index :photos, :taken_at if index_exists?(:photos, :taken_at)
    remove_index :photos, [:latitude, :longitude] if index_exists?(:photos, [:latitude, :longitude])
    remove_index :photos, :created_at if index_exists?(:photos, :created_at)
    remove_index :photos, :uploaded_by_id if index_exists?(:photos, :uploaded_by_id)
    remove_index :photos, :user_id if index_exists?(:photos, :user_id)
  end

  def down
    puts "This migration is irreversible due to data structure changes."
    puts "To rollback: first run Photo.destroy_all in console, then rollback manually."
    raise ActiveRecord::IrreversibleMigration
  end
end