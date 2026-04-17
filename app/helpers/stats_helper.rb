module StatsHelper
  def pace_estimates(user, path)
    avg_daily_miles = average_daily_miles(user, path)
    return [] unless avg_daily_miles&.positive?

    user_miles = user.step.total_miles

    upcoming_milestones(path, user_miles).map do |milestone|
      miles_away = milestone.cumulative_distance_miles - user_miles
      days_away = (miles_away / avg_daily_miles).ceil

      { name: milestone.name, miles_away: miles_away.round(1), estimated_date: Date.current + days_away }
    end
  end

  def personal_bests(user, path, limit: 5)
    DailyStepEntry
      .where(user: user, path: path)
      .order(steps: :desc)
      .limit(limit)
      .map { |entry| { date: entry.date, steps: entry.steps, miles: steps_to_miles(entry.steps) } }
  end

  private

  def average_daily_miles(user, path)
    avg_steps = DailyStepEntry.where(user: user, path: path).average(:steps)&.to_f
    avg_steps&.positive? ? avg_steps / Step::STEPS_PER_MILE : nil
  end

  def upcoming_milestones(path, user_miles)
    path.milestones.select { |m| m.cumulative_distance_miles > user_miles }
  end

  def steps_to_miles(steps)
    (steps.to_f / Step::STEPS_PER_MILE).round(2)
  end
end
