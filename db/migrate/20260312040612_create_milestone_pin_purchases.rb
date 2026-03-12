class CreateMilestonePinPurchases < ActiveRecord::Migration[8.0]
  def change
    create_table :milestone_pin_purchases do |t|
      t.references :user, null: false, foreign_key: true
      t.references :milestone, null: false, foreign_key: true

      t.timestamps
    end
    add_index :milestone_pin_purchases, [ :user_id, :milestone_id ], unique: true
  end
end
