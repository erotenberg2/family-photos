class AddSubeventIdToMedia < ActiveRecord::Migration[8.0]
  def change
    add_reference :media, :subevent, null: true, foreign_key: true
  end
end
