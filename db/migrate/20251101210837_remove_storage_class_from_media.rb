class RemoveStorageClassFromMedia < ActiveRecord::Migration[8.0]
  def change
    remove_column :media, :storage_class, :string
  end
end
