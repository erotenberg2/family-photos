class AddFamilyFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :first_name, :string
    add_column :users, :last_name, :string
    add_column :users, :role, :string, default: 'family_member', null: false
    add_column :users, :active, :boolean, default: true, null: false
    
    # Add indexes for common queries
    add_index :users, :role
    add_index :users, :active
    add_index :users, [:first_name, :last_name]
  end
end
