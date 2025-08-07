class CreateAlbums < ActiveRecord::Migration[8.0]
  def change
    create_table :albums do |t|
      t.string :title, null: false
      t.text :description
      t.references :cover_photo, null: true, foreign_key: { to_table: :photos }
      t.references :user, null: false, foreign_key: true
      t.boolean :private, default: false, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.timestamps
    end
    
    add_index :albums, :title
    add_index :albums, :private
  end
end
