class CreatePaths < ActiveRecord::Migration[8.0]
  def change
    create_table :paths do |t|
      t.string :name, null: false
      t.integer :part_number, null: false
      t.integer :total_distance_miles, null: false
      t.boolean :active, default: false

      t.timestamps
    end
  end
end
