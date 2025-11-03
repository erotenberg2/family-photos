class AddVersionsToMedia < ActiveRecord::Migration[8.0]
  def change
    add_column :media, :versions, :json, default: []
  end
end

