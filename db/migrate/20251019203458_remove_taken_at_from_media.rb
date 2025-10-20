class RemoveTakenAtFromMedia < ActiveRecord::Migration[8.0]
  def change
    remove_column :media, :taken_at, :datetime
    remove_index :media, :taken_at if index_exists?(:media, :taken_at)
  end
end
