class AddDatabaseConstraintsAndIndexes < ActiveRecord::Migration[8.0]
  def up
    # 1. Backfill any NULL token_color values before adding NOT NULL constraint
    User.where(token_color: nil).update_all(token_color: "#4169E1")
    change_column_null :users, :token_color, false

    # 2. Backfill any NULL map_position values before adding NOT NULL constraints
    Milestone.where(map_position_x: nil).update_all(map_position_x: 0)
    Milestone.where(map_position_y: nil).update_all(map_position_y: 0)
    change_column_null :milestones, :map_position_x, false
    change_column_null :milestones, :map_position_y, false

    # 3. Foreign key on path_users.current_milestone_id (nullable FK)
    add_foreign_key :path_users, :milestones, column: :current_milestone_id

    # 4. Index on path_users.current_milestone_id for FK lookups
    add_index :path_users, :current_milestone_id

    # 5. CHECK constraint on paths.part_number to match model validation
    add_check_constraint :paths, "part_number IN (1, 2)", name: "chk_paths_part_number"
  end

  def down
    remove_check_constraint :paths, name: "chk_paths_part_number"
    remove_index :path_users, :current_milestone_id
    remove_foreign_key :path_users, column: :current_milestone_id
    change_column_null :milestones, :map_position_y, true
    change_column_null :milestones, :map_position_x, true
    change_column_null :users, :token_color, true
  end
end
