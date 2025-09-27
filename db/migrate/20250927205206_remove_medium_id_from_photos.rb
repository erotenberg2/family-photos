class RemoveMediumIdFromPhotos < ActiveRecord::Migration[8.0]
  def change
    remove_column :photos, :medium_id, :bigint
  end
end
