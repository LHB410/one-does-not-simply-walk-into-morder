class CreateGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :groups do |t|
      t.string :name, null: false
      t.string :password_digest, null: false
      # FK added in RelaxUserAuthColumns to break the circular groups <-> users dependency.
      t.bigint :leader_id

      t.timestamps
    end

    add_index :groups, :leader_id
  end
end
