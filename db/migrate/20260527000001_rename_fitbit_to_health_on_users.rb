class RenameFitbitToHealthOnUsers < ActiveRecord::Migration[8.0]
  COLUMNS = {
    fitbit_uid: :health_uid,
    fitbit_access_token: :health_access_token,
    fitbit_refresh_token: :health_refresh_token,
    fitbit_token_expires_at: :health_token_expires_at,
    fitbit_last_sync_at: :health_last_sync_at
  }.freeze

  def up
    COLUMNS.each { |from, to| rename_column :users, from, to }

    # Fitbit tokens cannot be reused against the Google Health API, so clear
    # them. Every user re-consents once via "Connect Google Health". Step
    # history (steps, daily_step_entries, path_users) is untouched. Raw SQL
    # (not the User model) keeps this migration robust during release-phase runs.
    execute(<<~SQL.squish)
      UPDATE users SET
        health_uid = NULL,
        health_access_token = NULL,
        health_refresh_token = NULL,
        health_token_expires_at = NULL,
        health_last_sync_at = NULL
    SQL
  end

  def down
    COLUMNS.each { |from, to| rename_column :users, to, from }
  end
end
