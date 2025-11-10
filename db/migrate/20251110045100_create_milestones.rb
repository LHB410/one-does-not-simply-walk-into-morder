class CreateMilestones < ActiveRecord::Migration[8.0]
  def change
    create_table :milestones do |t|
      t.references :path, null: false, foreign_key: true
      t.string :name, null: false
      t.integer :distance_from_previous_miles, null: false
      t.integer :cumulative_distance_miles, null: false
      t.integer :sequence_order, null: false
      t.decimal :map_position_x
      t.decimal :map_position_y

      t.timestamps
    end
    add_index :milestones, [ :path_id, :sequence_order ], unique: true
  end
end
