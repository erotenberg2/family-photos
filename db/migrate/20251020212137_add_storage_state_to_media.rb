class AddStorageStateToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :storage_state, :string, default: 'unsorted', null: false
    add_index :media, :storage_state
  end
end
