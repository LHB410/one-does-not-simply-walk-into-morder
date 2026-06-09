# Closes a user's account and permanently deletes all of their data. This is the
# data-deletion path required for Google OAuth restricted-scope verification:
# disconnecting Google only stops syncing, whereas closing the account erases
# everything. Destroying the user cascades to their step counts, daily entries,
# path progress, and milestone pins via `dependent: :destroy`.
class AccountClosure
  include Loggable

  def initialize(user)
    @user = user
  end

  def call
    revoke_health_grant
    ActiveRecord::Base.transaction do
      reassign_or_close_group
      @user.destroy!
    end
    log(:info, "Account closed and data deleted for user #{@user.id}")
    true
  end

  private

  # Best-effort: revoke the grant on Google's side so the token dies everywhere,
  # not just locally. Done outside the transaction (it's a network call) and the
  # health columns aren't cleared because the row is about to be destroyed.
  def revoke_health_grant
    return unless @user.health_connected?

    HealthClient.revoke_token(@user.health_refresh_token || @user.health_access_token)
  end

  # A departing leader hands off to the next-joined remaining member; if they
  # were the last member, the now-empty group is removed. Non-leaders fall
  # through — destroying the user removes them from the group on its own.
  def reassign_or_close_group
    return unless @user.group_leader?

    group = @user.group
    next_leader = group.users.where.not(id: @user.id).order(:created_at, :id).first

    next_leader ? group.update!(leader: next_leader) : group.destroy!
  end
end
