class RelaxUserAuthColumns < ActiveRecord::Migration[8.0]
  def up
    # Group members authenticate against their group's shared password, so they
    # have no individual digest of their own.
    change_column_null :users, :password_digest, true

    # Deterministic Active Record Encryption ciphertext for email is much larger
    # than the plaintext and overflows varchar(255); widen to text. The unique
    # index on email is preserved across the varchar -> text change in Postgres.
    change_column :users, :email, :text

    # Added last (not inline on create_groups) so both tables exist first.
    # nullify avoids a dangling FK if a leader account is ever deleted.
    add_foreign_key :groups, :users, column: :leader_id, on_delete: :nullify
  end

  def down
    remove_foreign_key :groups, :users, column: :leader_id
    change_column :users, :email, :string
    change_column_null :users, :password_digest, false
  end
end
