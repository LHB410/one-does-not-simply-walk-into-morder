class FitnessAppSyncJob < ApplicationJob
  queue_as :default

  SYNC_HOUR = 23
  SYNC_MINUTE = 59
  CATCHUP_HOUR = 6
  CATCHUP_MINUTE = 0

  def perform(user_id, date = nil)
    user = User.find_by(id: user_id)
    return unless user&.fitness_app_connected?

    sync_date = date ? Date.parse(date) : Date.current
    FitnessAppSyncService.new(user).call(date: sync_date)

    schedule_next_run(user) unless date
  end

  def self.schedule_for(user)
    run_at = next_sync_time(user)
    set(wait_until: run_at).perform_later(user.id)
  end

  def self.next_sync_time(user)
    zone = user_zone(user)
    now = Time.current.in_time_zone(zone)
    tonight = now.change(hour: SYNC_HOUR, min: SYNC_MINUTE, sec: 0)

    tonight > now ? tonight : tonight + 1.day
  end

  def self.next_catchup_time(user)
    zone = user_zone(user)
    now = Time.current.in_time_zone(zone)
    morning = now.change(hour: CATCHUP_HOUR, min: CATCHUP_MINUTE, sec: 0)

    morning > now ? morning : morning + 1.day
  end

  def self.user_zone(user)
    zone = user.timezone.present? ? ActiveSupport::TimeZone[user.timezone] : nil
    zone || Time.zone
  end

  private

  def schedule_next_run(user)
    return unless user.fitness_app_connected?

    tomorrow = self.class.next_sync_time(user)
    self.class.set(wait_until: tomorrow).perform_later(user.id)

    catchup_at = self.class.next_catchup_time(user)
    self.class.set(wait_until: catchup_at).perform_later(user.id, Date.current.to_s)
  end
end
