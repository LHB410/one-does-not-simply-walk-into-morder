class FitbitClient
  API_BASE = "https://api.fitbit.com".freeze

  class TokenRefreshError < StandardError; end
  class ApiError < StandardError; end

  def initialize(user)
    @user = user
  end

  def self.oauth_client
    OAuth2::Client.new(
      ENV.fetch("FITBIT_CLIENT_ID"),
      ENV.fetch("FITBIT_CLIENT_SECRET"),
      authorize_url: ENV.fetch("FITBIT_AUTH_URL"),
      token_url: ENV.fetch("FITBIT_REFRESH_URL")
    )
  end

  def self.authorize_url(redirect_uri:, state:)
    oauth_client.auth_code.authorize_url(
      redirect_uri: redirect_uri,
      scope: "activity",
      response_type: "code",
      state: state
    )
  end

  def self.exchange_code(code:, redirect_uri:)
    oauth_client.auth_code.get_token(code, redirect_uri: redirect_uri)
  end

  def fetch_steps(date = Date.current)
    refresh_token_if_needed!
    response = request_steps(date)

    if response.status == 401
      Rails.logger.info("Fitbit 401 for user #{@user.id}, forcing token refresh and retrying")
      force_refresh_token!
      response = request_steps(date)
    end

    unless response.success?
      Rails.logger.error("Fitbit API error for user #{@user.id}: HTTP #{response.status} — #{response.body.truncate(200)}")
      raise ApiError, "Fitbit API returned HTTP #{response.status}"
    end

    steps = JSON.parse(response.body).dig("summary", "steps")
    if steps.nil?
      Rails.logger.error("Fitbit API response missing steps for user #{@user.id}: #{response.body.truncate(200)}")
      raise ApiError, "Fitbit API response missing 'summary.steps'"
    end

    steps.to_i
  end

  private

  def request_steps(date)
    connection.get("/1/user/-/activities/date/#{date.strftime('%Y-%m-%d')}.json")
  end

  def refresh_token_if_needed!
    return if @user.fitbit_token_expires_at.present? && @user.fitbit_token_expires_at.future?

    force_refresh_token!
  end

  def force_refresh_token!
    @connection = nil

    new_token = OAuth2::AccessToken.new(
      self.class.oauth_client,
      @user.fitbit_access_token,
      refresh_token: @user.fitbit_refresh_token
    ).refresh!

    @user.update!(
      fitbit_access_token: new_token.token,
      fitbit_refresh_token: new_token.refresh_token,
      fitbit_token_expires_at: Time.at(new_token.expires_at)
    )
  rescue OAuth2::Error => e
    Rails.logger.error("Fitbit token refresh failed for user #{@user.id}: #{e.message}")
    @user.update!(fitbit_access_token: nil, fitbit_refresh_token: nil,
                  fitbit_token_expires_at: nil)
    raise TokenRefreshError, "Token refresh failed — please reconnect Fitbit."
  end

  def connection
    @connection ||= Faraday.new(url: API_BASE) do |f|
      f.headers["Authorization"] = "Bearer #{@user.fitbit_access_token}"
      f.headers["Accept"] = "application/json"
    end
  end
end
