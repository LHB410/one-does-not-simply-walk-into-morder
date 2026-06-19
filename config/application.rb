require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

# Plain Rack middleware, referenced at boot before autoloading — require them
# explicitly (and keep them out of the lib autoloader below, like clock.rb).
require_relative "../lib/security_headers"
require_relative "../lib/mime_type_guard"

module OneDoesNotSimplyWalkIntoMorder
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    # Ignore clock.rb - it's a standalone clockwork config file, not a Rails module
    config.autoload_lib(ignore: %w[assets tasks clock.rb security_headers.rb mime_type_guard.rb])

    # Security headers on every response (static + error pages too) — outermost
    # so it wraps static-file and exception responses, not just controllers.
    config.middleware.insert_before 0, SecurityHeaders

    # Catch malformed Accept/Content-Type headers from scanners and answer a
    # clean 406. Mounted just inside DebugExceptions so we intercept the
    # InvalidType exception before it gets logged with a full backtrace.
    config.middleware.insert_after ActionDispatch::DebugExceptions, MimeTypeGuard

    # Active Record Encryption keys are read from the environment (dotenv in
    # dev/test, Heroku config vars in production) rather than Rails credentials.
    config.active_record.encryption.primary_key = ENV["AR_ENCRYPTION_PRIMARY_KEY"]
    config.active_record.encryption.deterministic_key = ENV["AR_ENCRYPTION_DETERMINISTIC_KEY"]
    config.active_record.encryption.key_derivation_salt = ENV["AR_ENCRYPTION_KEY_DERIVATION_SALT"]

    # Transition flags for migrating an existing plaintext database to encrypted.
    # Keep false normally; set both true only during the backfill window (see
    # lib/tasks/encryption.rake), then back to false.
    config.active_record.encryption.support_unencrypted_data =
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("AR_ENCRYPTION_SUPPORT_UNENCRYPTED", "false"))
    config.active_record.encryption.extend_queries =
      ActiveModel::Type::Boolean.new.cast(ENV.fetch("AR_ENCRYPTION_EXTEND_QUERIES", "false"))

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")
  end
end
