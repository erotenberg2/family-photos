class UpdateMediumDatetimeColumns < ActiveRecord::Migration[8.0]
  def up
    # Add new datetime columns to Medium
    add_column :media, :datetime_source_last_modified, :datetime
    add_column :media, :datetime_intrinsic, :datetime
    add_column :media, :datetime_user, :datetime
    add_column :media, :datetime_inferred, :datetime
    
    # Add indexes for the datetime columns
    add_index :media, :datetime_source_last_modified
    add_index :media, :datetime_intrinsic
    add_index :media, :datetime_user
    add_index :media, :datetime_inferred
    
    # Remove width and height from Medium (no data to preserve)
    remove_column :media, :width
    remove_column :media, :height
  end
  
  def down
    # Add width and height back to Medium
    add_column :media, :width, :integer
    add_column :media, :height, :integer
    
    # Remove the new datetime columns from Medium
    remove_column :media, :datetime_source_last_modified
    remove_column :media, :datetime_intrinsic
    remove_column :media, :datetime_user
    remove_column :media, :datetime_inferred
  end
end
