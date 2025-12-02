class CreateDailyStepEntries < ActiveRecord::Migration[8.0]
  def change
    create_table :daily_step_entries do |t|
      t.references :user, null: false, foreign_key: true
      t.references :path, null: false, foreign_key: true
      t.date :date, null: false
      t.integer :steps, null: false, default: 0

      t.timestamps
    end

    add_index :daily_step_entries, [ :user_id, :path_id, :date ], unique: true, name: "index_daily_step_entries_on_user_path_date"
  end
end
