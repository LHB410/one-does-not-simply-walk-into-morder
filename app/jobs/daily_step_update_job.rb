class DailyStepUpdateJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("Starting daily step update at #{Time.current}")

    service = GoogleSheetsService.new
    rows = service.fetch_user_steps_rows

    # Build steps data for today only (if date provided). If date column is missing,
    # fall back to processing all rows like before.
    steps_data = {}
    if rows.present?
      rows.each do |row|
        email = row[0]&.strip&.downcase
        steps_str = row[1]
        next unless email.present?
        steps_val = steps_str.to_i
        next unless steps_val > 0

        date_str = row[2]
        if date_str.present?
          begin
            tz = ActiveSupport::TimeZone["America/Chicago"]
            row_time = Time.parse(date_str.to_s)
            row_date_cst = row_time.in_time_zone(tz).to_date
            today_cst = Time.current.in_time_zone(tz).to_date
            next unless row_date_cst == today_cst
          rescue ArgumentError
            # If date is malformed, skip the row
            next
          end
        end
        steps_data[email] = steps_val
      end
      Rails.logger.info("Prepared step updates for #{steps_data.size} users")
    end

    if steps_data.empty?
      Rails.logger.warn("No step data retrieved from Google Sheets")
      return
    end

    updated_count = 0
    skipped_no_data = 0
    skipped_already_today = 0

    # Fetch active path once before the loop (memoized via Path.current)
    active_path = Path.current

    User.includes(:step, path_users: :path).find_each do |user|
      next unless steps_data.key?(user.email.downcase)

      step = user.step
      unless step.can_update_today?
        skipped_already_today += 1
        Rails.logger.info("Skipped #{user.email} (already updated today)")
        next
      end

      new_steps = steps_data[user.email.downcase]

      if step.add_steps(new_steps)
        # Update path progress
        path_user = user.current_position_on_path(active_path)
        path_user&.update_progress

        updated_count += 1
        Rails.logger.info("Updated #{user.email}: +#{new_steps} steps (total=#{step.total_steps})")
      else
        Rails.logger.error("Failed to update #{user.name}: #{step.errors.full_messages}")
      end
    end

    Rails.logger.info("Daily step update completed: updated=#{updated_count}, skipped_no_data=#{skipped_no_data}, skipped_already_today=#{skipped_already_today}")
  end
end
