require "signet/oauth_2/client"

class HealthClient
  API_BASE = "https://health.googleapis.com".freeze
  AUTHORIZE_URL = "https://accounts.google.com/o/oauth2/v2/auth".freeze
  TOKEN_URL = "https://oauth2.googleapis.com/token".freeze
  SCOPE = "https://www.googleapis.com/auth/googlehealth.activity_and_fitness.readonly".freeze

  class TokenRefreshError < StandardError; end
  class ApiError < StandardError; end

  def initialize(user)
    @user = user
  end

  def self.signet_client(redirect_uri: nil, refresh_token: nil)
    Signet::OAuth2::Client.new(
      authorization_uri: AUTHORIZE_URL,
      token_credential_uri: TOKEN_URL,
      client_id: ENV.fetch("GOOGLE_CLIENT_ID"),
      client_secret: ENV.fetch("GOOGLE_CLIENT_SECRET"),
      scope: SCOPE,
      redirect_uri: redirect_uri,
      refresh_token: refresh_token
    )
  end

  def self.authorize_url(redirect_uri:, state:)
    signet_client(redirect_uri: redirect_uri).authorization_uri(
      access_type: "offline",
      prompt: "consent",
      state: state
    ).to_s
  end

  def self.exchange_code(code:, redirect_uri:)
    client = signet_client(redirect_uri: redirect_uri)
    client.code = code
    client.fetch_access_token!
    client
  end

  # The Google user id is not returned with the token (unlike Fitbit), so it is
  # fetched separately. It is stored as the durable "connected" marker.
  def self.fetch_identity(access_token:)
    response = bearer_connection(access_token).get("/v4/users/me/identity")
    unless response.success?
      raise ApiError, "Google Health identity returned HTTP #{response.status}"
    end

    body = JSON.parse(response.body)
    body["healthUserId"] || body["legacyUserId"]
  end

  def self.bearer_connection(access_token)
    Faraday.new(url: API_BASE) do |f|
      f.headers["Authorization"] = "Bearer #{access_token}"
      f.headers["Accept"] = "application/json"
    end
  end

  def fetch_steps(date = Date.current)
    refresh_token_if_needed!
    response = request_steps(date)

    if response.status == 401
      Rails.logger.info("Google Health 401 for user #{@user.id}, forcing token refresh and retrying")
      force_refresh_token!
      response = request_steps(date)
    end

    unless response.success?
      Rails.logger.error("Google Health API error for user #{@user.id}: HTTP #{response.status} — #{response.body.truncate(200)}")
      raise ApiError, "Google Health API returned HTTP #{response.status}"
    end

    parse_steps(response.body)
  end

  private

  def request_steps(date)
    connection.post("/v4/users/me/dataTypes/steps/dataPoints:dailyRollUp") do |req|
      req.headers["Content-Type"] = "application/json"
      req.body = rollup_body(date).to_json
    end
  end

  # Closed-open civil-time range covering the single target day.
  def rollup_body(date)
    next_day = date.next_day
    {
      range: {
        start: { date: { year: date.year, month: date.month, day: date.day } },
        end: { date: { year: next_day.year, month: next_day.month, day: next_day.day } }
      },
      windowSizeDays: 1
    }
  end

  # dailyRollUp returns rollupDataPoints with steps.countSum (int64 as a string).
  # A day with no recorded steps yields no rollupDataPoints, which is a legitimate 0.
  def parse_steps(body)
    points = JSON.parse(body)["rollupDataPoints"] || []
    points.filter_map { |p| p.dig("steps", "countSum") }.sum(&:to_i)
  end

  def refresh_token_if_needed!
    return if @user.health_token_expires_at.present? && @user.health_token_expires_at.future?

    force_refresh_token!
  end

  def force_refresh_token!
    @connection = nil

    client = self.class.signet_client(refresh_token: @user.health_refresh_token)
    client.refresh!

    @user.update!(
      health_access_token: client.access_token,
      health_refresh_token: client.refresh_token.presence || @user.health_refresh_token,
      health_token_expires_at: client.expires_at
    )
  rescue Signet::AuthorizationError => e
    Rails.logger.error("Google Health token refresh failed for user #{@user.id}: #{e.message}")
    @user.update!(health_access_token: nil, health_refresh_token: nil,
                  health_token_expires_at: nil)
    raise TokenRefreshError, "Token refresh failed — please reconnect Google Health."
  end

  def connection
    @connection ||= self.class.bearer_connection(@user.health_access_token)
  end
end
