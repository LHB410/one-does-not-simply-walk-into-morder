module StatsHelper
  def pace_estimates(user, path)
    entries = DailyStepEntry.where(user: user, path: path)
    return [] if entries.none?

    avg_daily_steps = entries.average(:steps).to_f
    return [] if avg_daily_steps <= 0

    avg_daily_miles = avg_daily_steps / Step::STEPS_PER_MILE
    user_miles = user.step.total_miles

    path.milestones.select { |m| m.cumulative_distance_miles > user_miles }.map do |milestone|
      miles_away = milestone.cumulative_distance_miles - user_miles
      days_away = (miles_away / avg_daily_miles).ceil

      {
        name: milestone.name,
        miles_away: miles_away.round(1),
        estimated_date: Date.current + days_away
      }
    end
  end

  def personal_bests(user, path, limit: 5)
    entries = DailyStepEntry.where(user: user, path: path)
                            .order(steps: :desc)
                            .limit(limit)

    entries.map do |entry|
      {
        date: entry.date,
        steps: entry.steps,
        miles: (entry.steps.to_f / Step::STEPS_PER_MILE).round(2)
      }
    end
  end
end
