class HealthSyncJob < ApplicationJob
  queue_as :default

  SYNC_HOUR = 23
  SYNC_MINUTE = 59
  CATCHUP_HOUR = 6
  CATCHUP_MINUTE = 0

  def perform(user_id, date = nil, token = nil)
    user = User.find_by(id: user_id)
    return unless user&.health_connected?
    # Ignore jobs from a superseded schedule: each connect mints a fresh token, so
    # any older chain (e.g. left over from a reconnect) no longer matches and stops
    # here — neither syncing nor rescheduling. This is what prevents duplicates.
    return if token != user.health_sync_token

    # Default to "today" in the USER's timezone, not the server's (UTC). The job
    # fires at 23:59 local, which for users behind UTC is already the next UTC
    # day — using Date.current there would sync the wrong (near-empty) day.
    sync_date = date ? Date.parse(date) : self.class.local_date(user)
    HealthSyncService.new(user).call(date: sync_date)

    schedule_next_run(user, token) unless date
  end

  def self.schedule_for(user)
    token = SecureRandom.hex(16)
    user.update!(health_sync_token: token)
    set(wait_until: next_sync_time(user)).perform_later(user.id, nil, token)
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

  # The current calendar date in the user's own timezone.
  def self.local_date(user)
    Time.current.in_time_zone(user_zone(user)).to_date
  end

  private

  def schedule_next_run(user, token)
    return unless user.health_connected?

    tomorrow = self.class.next_sync_time(user)
    self.class.set(wait_until: tomorrow).perform_later(user.id, nil, token)

    catchup_at = self.class.next_catchup_time(user)
    self.class.set(wait_until: catchup_at).perform_later(user.id, self.class.local_date(user).to_s, token)
  end
end
