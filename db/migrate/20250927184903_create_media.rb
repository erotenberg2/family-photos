class CreateMedia < ActiveRecord::Migration[8.0]
  def change
    create_table :media do |t|
      t.string :file_path, null: false
      t.integer :file_size
      t.string :original_filename
      t.string :content_type
      t.string :md5_hash, null: false
      t.integer :width
      t.integer :height
      t.datetime :taken_at
      t.references :uploaded_by, null: false, foreign_key: { to_table: :users }
      t.references :user, null: false, foreign_key: true
      t.string :medium_type, null: false
      t.references :mediable, polymorphic: true, null: false

      t.timestamps
    end
    
    add_index :media, :file_path, unique: true
    add_index :media, :md5_hash, unique: true
    add_index :media, :medium_type
    add_index :media, :taken_at
    add_index :media, :created_at
  end
end
