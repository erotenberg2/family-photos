class AddStorageClassToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :storage_class, :string, default: 'unsorted', null: false
    add_index :media, :storage_class
  end
end
