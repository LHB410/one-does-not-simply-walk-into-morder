class FitbitSyncService
  def initialize(user)
    @user = user
    @client = FitbitClient.new(user)
  end

  def call
    return false unless @user.fitbit_uid.present?

    fitbit_steps = @client.fetch_steps(Date.current)
    return true if fitbit_steps.zero?

    active_path = Path.current
    return false unless active_path

    record_steps(fitbit_steps, active_path)
    @user.update!(fitbit_last_sync_at: Time.current)

    Rails.logger.info("Fitbit sync for user #{@user.id}: #{fitbit_steps} steps")
    true
  rescue FitbitClient::TokenRefreshError => e
    Rails.logger.warn("Fitbit sync skipped for user #{@user.id}: #{e.message}")
    false
  rescue StandardError => e
    Rails.logger.error("Fitbit sync failed for user #{@user.id}: #{e.class} — #{e.message}")
    false
  end

  private

  def record_steps(fitbit_steps, active_path)
    step = @user.step
    existing_entry = DailyStepEntry.find_by(user: @user, path: active_path, date: Date.current)
    previously_recorded = existing_entry&.steps.to_i
    delta = fitbit_steps - previously_recorded

    if delta <= 0
      Rails.logger.info("Fitbit sync user #{@user.id}: no step update (fitbit=#{fitbit_steps}, already=#{previously_recorded}, delta=#{delta})")
      return
    end

    step.transaction do
      step.update!(
        steps_today: fitbit_steps,
        total_steps: step.total_steps - previously_recorded + fitbit_steps,
        last_updated_date: Date.current
      )
      step.send(:recalculate_distances)
      step.save!

      if existing_entry
        existing_entry.update!(steps: fitbit_steps)
      else
        DailyStepEntry.create!(user: @user, path: active_path, date: Date.current, steps: fitbit_steps)
      end

      @user.current_position_on_path(active_path)&.update_progress(active_path)
    end
  end
end
