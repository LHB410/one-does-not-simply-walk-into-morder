# Backfill a user's steps for a past day

Sets a day's steps to the correct value, then rebuilds the cumulative total and map
progress from the daily entries (the source of truth). Idempotent.

Run via `heroku run --app walk-to-mordor rails console` and paste:

```ruby
user_id = 7
date    = Date.new(2026, 6, 9)
steps   = 11712

user  = User.find(user_id)
path  = Path.current
step  = user.step

DailyStepEntry.find_or_initialize_by(user: user, path: path, date: date).update!(steps: steps)

step.total_steps = DailyStepEntry.where(user: user, path: path).sum(:steps)
step.steps_today = steps
step.send(:recalculate_distances)
step.save!

user.path_users.where(path: path).find_each { |pu| pu.update_progress(path) }
```
