class CreateAudios < ActiveRecord::Migration[8.0]
  def change
    create_table :audios do |t|
      t.string :title
      t.text :description
      t.integer :duration
      t.integer :bitrate
      t.string :artist
      t.string :album
      t.string :genre

      t.timestamps
    end
  end
end
