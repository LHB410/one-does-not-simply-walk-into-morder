# Shared logging helper. Include in any service, job, controller, or model to
# get a terse `log(level, message)` wrapper over Rails.logger.
module Loggable
  private

  def log(level, message)
    Rails.logger.public_send(level, message)
  end
end
