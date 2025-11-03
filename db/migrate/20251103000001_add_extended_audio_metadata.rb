class AddExtendedAudioMetadata < ActiveRecord::Migration[8.0]
  def change
    add_column :audios, :year, :integer
    add_column :audios, :track, :string
    add_column :audios, :comment, :text
    add_column :audios, :album_artist, :string
    add_column :audios, :composer, :string
    add_column :audios, :disc_number, :string
    add_column :audios, :bpm, :integer
    add_column :audios, :compilation, :boolean, default: false
    add_column :audios, :publisher, :string
    add_column :audios, :copyright, :string
    add_column :audios, :isrc, :string
    add_column :audios, :cover_art_path, :string
    add_column :audios, :metadata, :json, default: {}

    add_index :audios, :year
    add_index :audios, [:artist, :album]
    add_index :audios, :compilation
  end
end

