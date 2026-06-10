class AddHealthSyncTokenToUsers < ActiveRecord::Migration[8.0]
  # Identifies the user's current sync-schedule "generation". Each Google Health
  # connect mints a fresh token; a HealthSyncJob only runs if it still carries the
  # user's current token, so reconnecting supersedes any prior schedule chain
  # instead of stacking duplicates.
  # text (not string) so the non-deterministic encrypted ciphertext fits, matching
  # the other encrypted token columns (health_access_token / health_refresh_token).
  def change
    add_column :users, :health_sync_token, :text
  end
end
