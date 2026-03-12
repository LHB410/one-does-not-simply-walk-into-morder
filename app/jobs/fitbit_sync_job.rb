class FitbitSyncJob < ApplicationJob
  queue_as :default

  SYNC_HOUR = 23
  SYNC_MINUTE = 59

  def perform(user_id)
    user = User.find_by(id: user_id)
    return unless user&.fitbit_connected?

    FitbitSyncService.new(user).call

    schedule_next_run(user)
  end

  def self.schedule_for(user)
    run_at = next_sync_time(user)
    set(wait_until: run_at).perform_later(user.id)
  end

  def self.next_sync_time(user)
    zone = user.timezone.present? ? ActiveSupport::TimeZone[user.timezone] : nil
    zone ||= Time.zone
    now = Time.current.in_time_zone(zone)
    tonight = now.change(hour: SYNC_HOUR, min: SYNC_MINUTE, sec: 0)

    tonight > now ? tonight : tonight + 1.day
  end

  private

  def schedule_next_run(user)
    return unless user.fitbit_connected?

    tomorrow = self.class.next_sync_time(user)
    self.class.set(wait_until: tomorrow).perform_later(user.id)
  end
end
