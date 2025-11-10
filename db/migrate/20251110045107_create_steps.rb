class CreateSteps < ActiveRecord::Migration[8.0]
  def change
    create_table :steps do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.integer :total_steps, default: 0, null: false
      t.integer :steps_today, default: 0, null: false
      t.integer :steps_until_mordor, null: false
      t.integer :steps_until_next_milestone, null: false
      t.date :last_updated_date

      t.timestamps
    end
  end
end
