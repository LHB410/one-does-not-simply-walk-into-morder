class CreatePathUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :path_users do |t|
      t.references :path, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :current_milestone_id
      t.decimal :progress_percentage, default: 0.0

      t.timestamps
    end
    add_index :path_users, [ :path_id, :user_id ], unique: true
  end
end
