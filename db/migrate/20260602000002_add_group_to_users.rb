class AddGroupToUsers < ActiveRecord::Migration[8.0]
  def change
    # Nullable: admins and pre-existing (pre-groups) users have no group.
    add_reference :users, :group, foreign_key: true, null: true, index: true
  end
end
