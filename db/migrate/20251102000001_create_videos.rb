class CreateVideos < ActiveRecord::Migration[8.0]
  def change
    create_table :videos do |t|
      t.string :title
      t.text :description
      t.integer :duration
      t.integer :width
      t.integer :height
      t.integer :bitrate
      t.string :camera_make
      t.string :camera_model
      t.string :thumbnail_path
      t.integer :thumbnail_width
      t.integer :thumbnail_height
      t.string :preview_path
      t.integer :preview_width
      t.integer :preview_height
      t.json :metadata, default: {}

      t.timestamps
    end

    add_index :videos, [:width, :height]
    add_index :videos, :duration
  end
end

