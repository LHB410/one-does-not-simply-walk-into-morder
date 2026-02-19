class AddFitbitFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    change_table :users, bulk: true do |t|
      t.string :fitbit_uid
      t.text :fitbit_access_token
      t.text :fitbit_refresh_token
      t.datetime :fitbit_token_expires_at
      t.datetime :fitbit_last_sync_at
    end
  end
end
