class CreateSubevents < ActiveRecord::Migration[8.0]
  def change
    create_table :subevents do |t|
      t.string :title
      t.text :description
      t.references :event, null: false, foreign_key: true
      t.references :parent_subevent, null: true, foreign_key: { to_table: :subevents }

      t.timestamps
    end
  end
end
