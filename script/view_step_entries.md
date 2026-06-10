# Step entries report (June 8 & 9)

Paste into a prod Rails console (`heroku run rails console`). Prints a Markdown
table — one row per user, one column per date. `DailyStepEntry` is the immutable
audit log, so this is the source of truth for what each member logged.

Add dates to the `dates` array to widen the table.

```ruby
dates = [Date.new(2026, 6, 7), Date.new(2026, 6, 8), Date.new(2026, 6, 9), Date.new(2026, 6, 10)]

entries = DailyStepEntry.where(date: dates).includes(:user)

by_user = Hash.new { |h, k| h[k] = {} }
entries.each { |e| by_user[e.user][e.date] = e.steps }

headers = ["Name"] + dates.map { |d| d.strftime("%b %-d") }
puts "| #{headers.join(' | ')} |"
puts "| #{headers.map { '---' }.join(' | ')} |"

by_user.keys.sort_by(&:name).each do |user|
  cells = [user.name] + dates.map { |d| by_user[user][d]&.to_s || "-" }
  puts "| #{cells.join(' | ')} |"
end

puts
puts "_#{by_user.size} users_"
```
