class HealthSyncService
  def initialize(user)
    @user = user
    @client = HealthClient.new(user)
  end

  def call(date: Date.current)
    unless @user.health_uid.present?
      Rails.logger.warn("Health sync aborted for user #{@user.id}: no health_uid")
      return false
    end

    synced_steps = @client.fetch_steps(date)
    if synced_steps.zero?
      Rails.logger.info("Health sync user #{@user.id}: provider returned 0 steps for #{date}, skipping")
      return true
    end

    active_path = Path.current
    unless active_path
      Rails.logger.warn("Health sync aborted for user #{@user.id}: no active path (Path.current is nil)")
      return false
    end

    record_steps(synced_steps, active_path, date)
    @user.update!(health_last_sync_at: Time.current)

    Rails.logger.info("Health sync for user #{@user.id}: #{synced_steps} steps on #{date}")
    true
  rescue HealthClient::TokenRefreshError => e
    Rails.logger.warn("Health sync skipped for user #{@user.id}: #{e.message}")
    false
  rescue StandardError => e
    Rails.logger.error("Health sync failed for user #{@user.id}: #{e.class} — #{e.message}")
    false
  end

  private

  def record_steps(synced_steps, active_path, date)
    step = @user.step
    existing_entry = DailyStepEntry.find_by(user: @user, path: active_path, date: date)
    previously_recorded = existing_entry&.steps.to_i
    delta = synced_steps - previously_recorded

    if delta <= 0
      Rails.logger.info("Health sync user #{@user.id}: no step update (synced=#{synced_steps}, already=#{previously_recorded}, delta=#{delta})")
      return
    end

    step.transaction do
      step.update!(
        steps_today: synced_steps,
        total_steps: step.total_steps - previously_recorded + synced_steps,
        last_updated_date: date
      )
      step.send(:recalculate_distances)
      step.save!

      if existing_entry
        existing_entry.update!(steps: synced_steps)
      else
        DailyStepEntry.create!(user: @user, path: active_path, date: date, steps: synced_steps)
      end

      @user.current_position_on_path(active_path)&.update_progress(active_path)
    end
  end
end
