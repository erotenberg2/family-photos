class AddPrimaryToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :primary, :string, null: true
    add_index :media, :primary
  end
end

