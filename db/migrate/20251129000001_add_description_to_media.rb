class AddDescriptionToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :description, :string, null: false, default: ""
    add_index :media, :description
  end
end

