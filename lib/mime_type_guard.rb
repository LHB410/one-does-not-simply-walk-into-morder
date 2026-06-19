# Rack middleware that catches malformed Accept/Content-Type headers (e.g. a
# bare "*" instead of "*/*") sent by scanners and broken HTTP clients. Rails
# raises ActionDispatch::Http::MimeNegotiation::InvalidType for these, and
# DebugExceptions logs a full backtrace on every hit — pure noise from bot
# traffic. We answer a clean 406 and log one terse info line instead.
#
# Mounted just INSIDE ActionDispatch::DebugExceptions (see config/application.rb)
# so we intercept the exception before it is logged with a backtrace.
class MimeTypeGuard
  NOT_ACCEPTABLE = [
    406,
    { "Content-Type" => "text/plain" },
    [ "Not Acceptable\n" ]
  ].freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    @app.call(env)
  rescue ActionDispatch::Http::MimeNegotiation::InvalidType => e
    log_rejected(env, e)
    NOT_ACCEPTABLE
  end

  private

  def log_rejected(env, error)
    Rails.logger.info(
      "Rejected malformed media type (406): " \
      "#{env['REQUEST_METHOD']} #{env['PATH_INFO']} — #{error.message}"
    )
  end
end
