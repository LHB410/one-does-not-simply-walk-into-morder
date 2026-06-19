# Find / fix step entries stamped on the wrong calendar day

Background: before the 3.2.4 fix, a **manual** step update used `Date.current`
(UTC), so the entry was dated by the server's UTC day, not the member's local
day. For members **behind** UTC (the Americas) a late-evening log was stamped a
day **ahead**; for members **ahead** of UTC (e.g. Tokyo) an early-morning log
was stamped a day **behind**. This finds those entries and (optionally) re-dates
them to the day they were actually logged, in the member's own timezone.

How it's detected: for each entry we compute the user's **local** date at the
moment it was created (`created_at` reinterpreted in their timezone). A mismatch
between that and `entry.date` is the signature.

Two directions, handled differently to avoid false positives from the sync job:
- **Ahead** (`entry.date` later than the local creation date) is *always* the
  manual bug — no job path ever stamps a future date. Flagged for every user.
- **Behind** (`entry.date` earlier) is also the bug **only for manual-only
  users** (those who never connected Google Health, so `timezone` was blank and
  they have no job entries). For Health-connected users the sync job's 6 AM
  catch-up legitimately writes *yesterday's* date, so "behind" is ignored there.

Safety:
- **Dry run by default** — `apply = false` writes nothing. You must consciously
  set `apply = true` to change data, and even then only "clean" rows move.
- **Collisions are never auto-fixed.** If the corrected date already has an
  entry (e.g. Austin already has a Jun 9 row), re-dating would violate the unique
  `(user, path, date)` index or silently change that day's total. Listed for a
  human instead.
- **Backfill timezones first.** Entries for users still missing a timezone can't
  be assessed and are skipped (reported, never changed). Run the timezone
  backfill before this so all members are covered.
- Clean re-dates don't touch `Step#total_steps` (cumulative total is unchanged —
  only which day the steps are attributed to moves), so totals stay correct.

Paste into a prod console (`heroku run rails console`).

```ruby
apply = false   # DRY RUN. Leave false to preview. Set true ONLY to apply clean re-dates.

candidates  = []   # [entry, corrected_date]            — safe to move
collisions  = []   # [entry, corrected_date, clash]     — needs a human
no_timezone = []   # entries we can't assess

DailyStepEntry.includes(:user).find_each do |entry|
  user = entry.user
  if user.timezone.blank?
    no_timezone << entry
    next
  end

  created_local = entry.created_at.in_time_zone(user.timezone).to_date
  next if entry.date == created_local                # correctly dated

  ahead       = entry.date > created_local
  manual_only = !user.health_connected?              # no job entries to confuse
  next unless ahead || manual_only                   # ignore job catch-up "behind" entries

  clash = DailyStepEntry.find_by(
    user_id: entry.user_id, path_id: entry.path_id, date: created_local
  )

  if clash && clash.id != entry.id
    collisions << [entry, created_local, clash]
  else
    candidates << [entry, created_local]
  end
end

puts "Clean re-dates: #{candidates.size}   Collisions (review): #{collisions.size}   No-timezone (skipped): #{no_timezone.size}"
puts

candidates.each do |entry, corrected|
  dir = entry.date > corrected ? "ahead" : "behind"
  puts "[clean/#{dir}] #{entry.user.name}  id=#{entry.id}  #{entry.date} -> #{corrected}  steps=#{entry.steps}  (created #{entry.created_at} UTC)"
end

collisions.each do |entry, corrected, clash|
  puts "[CLASH] #{entry.user.name}  id=#{entry.id}  #{entry.date} (#{entry.steps} steps) -> #{corrected}, " \
       "but #{corrected} already has id=#{clash.id} (#{clash.steps} steps) — review manually"
end

if no_timezone.any?
  names = no_timezone.map { |e| e.user.name }.uniq
  puts
  puts "Skipped (no timezone — backfill first): #{no_timezone.size} entries across #{names.size} users: #{names.join(', ')}"
end

if apply
  puts
  puts "APPLYING #{candidates.size} clean re-dates (collisions untouched)..."
  DailyStepEntry.transaction do
    candidates.each { |entry, corrected| entry.update!(date: corrected) }
  end
  puts "Done."
else
  puts
  puts "DRY RUN — nothing changed. Review the rows above, then set `apply = true` and re-run to apply ONLY the clean ones."
end
```
