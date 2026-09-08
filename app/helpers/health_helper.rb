module HealthHelper
  # Google expires an unverified app's Health grant 7 days after consent; a fixed
  # 6-day cycle always lands inside that window, whenever a member last connected.
  REMINDER_EPOCH = Date.new(2026, 9, 8)
  REMINDER_INTERVAL_DAYS = 6

  def health_reminder_due?(user)
    return false unless user&.health_connected?

    user.health_needs_reconnect? || renewal_day?
  end

  private

  def renewal_day?
    (Date.current - REMINDER_EPOCH).to_i % REMINDER_INTERVAL_DAYS == 0
  end
end
