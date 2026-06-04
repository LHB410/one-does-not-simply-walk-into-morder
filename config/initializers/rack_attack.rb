# Be sure to restart your server when you modify this file.
#
# Rack::Attack throttles abusive traffic at the rack layer (before it reaches
# the app). The primary goal is brute-force / credential-stuffing protection on
# login: because a whole group shares one password, a single guessed credential
# grants access to every member's data, so the login limit is deliberately tight.

# Throttle counters live in the durable, shared cache in real environments so a
# limit holds across processes/dynos. The test environment uses a null cache, so
# fall back to an in-memory store there to make throttling observable.
Rack::Attack.cache.store =
  Rails.env.test? ? ActiveSupport::Cache::MemoryStore.new : Rails.cache

# --- Login brute-force / credential-stuffing protection ---------------------
Rack::Attack::LOGIN_MAX_ATTEMPTS = 10
Rack::Attack::LOGIN_PERIOD = 1.minute

Rack::Attack.throttle(
  "logins/ip",
  limit: Rack::Attack::LOGIN_MAX_ATTEMPTS,
  period: Rack::Attack::LOGIN_PERIOD
) do |req|
  req.ip if req.path == "/login" && req.post?
end

# --- Global per-IP request flood safety net ---------------------------------
# A catch-all limit for any single IP. Static assets and the health check are
# exempt so deploys/monitoring are never throttled.
Rack::Attack::GLOBAL_MAX_REQUESTS = 300
Rack::Attack::GLOBAL_PERIOD = 5.minutes

Rack::Attack.throttle(
  "req/ip",
  limit: Rack::Attack::GLOBAL_MAX_REQUESTS,
  period: Rack::Attack::GLOBAL_PERIOD
) do |req|
  req.ip unless req.path.start_with?("/assets", "/up")
end

# Respond to throttled requests with a plain 429 and a Retry-After hint rather
# than a blank/odd error page.
Rack::Attack.throttled_responder = lambda do |request|
  match_data = request.env["rack.attack.match_data"] || {}
  retry_after = match_data[:period].to_s

  [
    429,
    { "Content-Type" => "text/plain", "Retry-After" => retry_after },
    [ "Too many requests. Please slow down and try again later.\n" ]
  ]
end
