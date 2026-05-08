class RenameFitbitToFitnessAppOnUsers < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :fitbit_uid, :fitness_app_uid
    rename_column :users, :fitbit_access_token, :fitness_app_access_token
    rename_column :users, :fitbit_refresh_token, :fitness_app_refresh_token
    rename_column :users, :fitbit_token_expires_at, :fitness_app_token_expires_at
    rename_column :users, :fitbit_last_sync_at, :fitness_app_last_sync_at
    add_column :users, :fitness_app_provider, :string

    reversible do |dir|
      dir.up do
        execute <<-SQL.squish
          UPDATE users SET fitness_app_provider = 'fitbit'
          WHERE fitness_app_uid IS NOT NULL
        SQL
      end
    end
  end
end
