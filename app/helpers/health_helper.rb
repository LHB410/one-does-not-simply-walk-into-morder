module HealthHelper
  # Google expires an unverified app's Health grant 7 days after consent. Rather
  # than track a renewal date per user, the whole app is prompted on one fixed
  # cycle: 6 < 7, so whenever a member last connected, the next prompt always
  # lands inside their window. Anchored to the release that introduced it.
  REMINDER_EPOCH = Date.new(2026, 9, 8)
  REMINDER_INTERVAL_DAYS = 6

  # Cycle days catch everyone before they lapse; the lapsed check is the safety
  # net for anyone who wasn't in the app on the day.
  def health_reminder_due?(user)
    return false unless user&.health_connected?

    user.health_needs_reconnect? || renewal_day?
  end

  private

  def renewal_day?
    (Date.current - REMINDER_EPOCH).to_i % REMINDER_INTERVAL_DAYS == 0
  end
end
