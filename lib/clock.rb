require "clockwork"
include Clockwork
require "active_support/time"

# Set timezone for clockwork (CST)
ENV["TZ"] = "America/Chicago"



# Run at 11:59 PM CST daily
every(1.day, "daily.step.update", at: "23:59") do
  DailyStepUpdateJob.perform_now
end
