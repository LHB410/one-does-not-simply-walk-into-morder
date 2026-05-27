class HealthSyncService
  include Loggable

  def initialize(user)
    @user = user
    @client = HealthClient.new(user)
  end

  def call(date: Date.current)
    return false unless connected?

    synced_steps = @client.fetch_steps(date)
    return true if zero_steps_reported?(synced_steps, date)
    return false unless active_path

    record_steps(synced_steps, date)
    mark_synced(synced_steps, date)
    true
  rescue HealthClient::TokenRefreshError => e
    log(:warn, "Health sync skipped for user #{@user.id}: #{e.message}")
    false
  rescue StandardError => e
    log(:error, "Health sync failed for user #{@user.id}: #{e.class} — #{e.message}")
    false
  end

  private

  def connected?
    return true if @user.health_uid.present?

    log(:warn, "Health sync aborted for user #{@user.id}: no health_uid")
    false
  end

  def zero_steps_reported?(synced_steps, date)
    return false unless synced_steps.zero?

    log(:info, "Health sync user #{@user.id}: provider returned 0 steps for #{date}, skipping")
    true
  end

  def active_path
    @active_path ||= Path.current
    return @active_path if @active_path

    log(:warn, "Health sync aborted for user #{@user.id}: no active path (Path.current is nil)")
    nil
  end

  def mark_synced(synced_steps, date)
    @user.update!(health_last_sync_at: Time.current)
    log(:info, "Health sync for user #{@user.id}: #{synced_steps} steps on #{date}")
  end

  def record_steps(synced_steps, date)
    entry = existing_entry(date)
    delta = synced_steps - recorded_steps(entry)
    return if already_up_to_date?(synced_steps, entry, delta)

    persist_steps(synced_steps, entry, date)
  end

  def existing_entry(date)
    DailyStepEntry.find_by(user: @user, path: active_path, date: date)
  end

  def recorded_steps(entry)
    entry&.steps.to_i
  end

  def already_up_to_date?(synced_steps, entry, delta)
    return false if delta.positive?

    log(:info, "Health sync user #{@user.id}: no step update (synced=#{synced_steps}, already=#{recorded_steps(entry)}, delta=#{delta})")
    true
  end

  def persist_steps(synced_steps, entry, date)
    @user.step.transaction do
      update_step_totals(synced_steps, recorded_steps(entry), date)
      upsert_daily_entry(entry, synced_steps, date)
      advance_path_progress
    end
  end

  def update_step_totals(synced_steps, previously_recorded, date)
    step = @user.step
    step.update!(
      steps_today: synced_steps,
      total_steps: step.total_steps - previously_recorded + synced_steps,
      last_updated_date: date
    )
    step.send(:recalculate_distances)
    step.save!
  end

  def upsert_daily_entry(entry, synced_steps, date)
    if entry
      entry.update!(steps: synced_steps)
    else
      DailyStepEntry.create!(user: @user, path: active_path, date: date, steps: synced_steps)
    end
  end

  def advance_path_progress
    @user.current_position_on_path(active_path)&.update_progress(active_path)
  end
end
