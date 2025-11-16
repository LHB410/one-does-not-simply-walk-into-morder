require "clockwork"
require "active_support/time"
require_relative "../config/environment"

include Clockwork

configure do |config|
  config[:tz] = "America/Chicago" # CST
end

# Run at 11:59 PM CST daily
every(1.day, "daily.step.update", at: "23:59") do
  DailyStepUpdateJob.perform_later
end
