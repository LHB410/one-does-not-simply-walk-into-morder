class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :name, null: false
      t.string :email, index: { unique: true }, null: false
      t.string :password_digest, null: false
      t.boolean :admin, default: false
      t.string :token_color

      t.timestamps
    end
  end
end
