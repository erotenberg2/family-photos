class AddLocationToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :latitude, :decimal, precision: 10, scale: 7
    add_column :media, :longitude, :decimal, precision: 10, scale: 7
    
    add_index :media, :latitude
    add_index :media, :longitude
  end
end
