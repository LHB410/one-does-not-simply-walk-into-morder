class FitnessAppSyncService
  def initialize(user)
    @user = user
    @client = FitnessAppClient.new(user)
  end

  def call(date: Date.current)
    unless @user.fitness_app_uid.present?
      Rails.logger.warn("Fitness app sync aborted for user #{@user.id}: no fitness_app_uid")
      return false
    end

    fetched_steps = @client.fetch_steps(date)
    if fetched_steps.zero?
      Rails.logger.info("Fitness app sync user #{@user.id}: returned 0 steps for #{date}, skipping")
      return true
    end

    active_path = Path.current
    unless active_path
      Rails.logger.warn("Fitness app sync aborted for user #{@user.id}: no active path (Path.current is nil)")
      return false
    end

    record_steps(fetched_steps, active_path, date)
    @user.update!(fitness_app_last_sync_at: Time.current)

    Rails.logger.info("Fitness app sync for user #{@user.id}: #{fetched_steps} steps on #{date}")
    true
  rescue FitnessAppClient::TokenRefreshError => e
    Rails.logger.warn("Fitness app sync skipped for user #{@user.id}: #{e.message}")
    false
  rescue StandardError => e
    Rails.logger.error("Fitness app sync failed for user #{@user.id}: #{e.class} — #{e.message}")
    false
  end

  private

  def record_steps(fetched_steps, active_path, date)
    step = @user.step
    existing_entry = DailyStepEntry.find_by(user: @user, path: active_path, date: date)
    previously_recorded = existing_entry&.steps.to_i
    delta = fetched_steps - previously_recorded

    if delta <= 0
      Rails.logger.info("Fitness app sync user #{@user.id}: no step update (fetched=#{fetched_steps}, already=#{previously_recorded}, delta=#{delta})")
      return
    end

    step.transaction do
      step.update!(
        steps_today: fetched_steps,
        total_steps: step.total_steps - previously_recorded + fetched_steps,
        last_updated_date: date
      )
      step.send(:recalculate_distances)
      step.save!

      if existing_entry
        existing_entry.update!(steps: fetched_steps)
      else
        DailyStepEntry.create!(user: @user, path: active_path, date: date, steps: fetched_steps)
      end

      @user.current_position_on_path(active_path)&.update_progress(active_path)
    end
  end
end
