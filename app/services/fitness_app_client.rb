class FitnessAppClient
  API_BASE = "https://api.fitbit.com".freeze

  class TokenRefreshError < StandardError; end
  class ApiError < StandardError; end

  def initialize(user, provider = nil)
    @user = user
    @provider = provider || user.fitness_app_provider
  end

  def self.oauth_client(provider = "fitbit")
    prefix = provider.upcase
    OAuth2::Client.new(
      ENV.fetch("#{prefix}_CLIENT_ID"),
      ENV.fetch("#{prefix}_CLIENT_SECRET"),
      authorize_url: ENV.fetch("#{prefix}_AUTH_URL"),
      token_url: ENV.fetch("#{prefix}_REFRESH_URL")
    )
  end

  def self.authorize_url(redirect_uri:, state:, provider: "fitbit")
    oauth_client(provider).auth_code.authorize_url(
      redirect_uri: redirect_uri,
      scope: "activity",
      response_type: "code",
      state: state
    )
  end

  def self.exchange_code(code:, redirect_uri:, provider: "fitbit")
    oauth_client(provider).auth_code.get_token(code, redirect_uri: redirect_uri)
  end

  def fetch_steps(date = Date.current)
    refresh_token_if_needed!
    response = request_steps(date)

    if response.status == 401
      Rails.logger.info("Fitness app 401 for user #{@user.id} (#{@provider}), forcing token refresh and retrying")
      force_refresh_token!
      response = request_steps(date)
    end

    unless response.success?
      Rails.logger.error("Fitness app API error for user #{@user.id} (#{@provider}): HTTP #{response.status} — #{response.body.truncate(200)}")
      raise ApiError, "Fitness app API returned HTTP #{response.status}"
    end

    steps = JSON.parse(response.body).dig("summary", "steps")
    if steps.nil?
      Rails.logger.error("Fitness app API response missing steps for user #{@user.id} (#{@provider}): #{response.body.truncate(200)}")
      raise ApiError, "Fitness app API response missing 'summary.steps'"
    end

    steps.to_i
  end

  private

  def request_steps(date)
    connection.get("/1/user/-/activities/date/#{date.strftime('%Y-%m-%d')}.json")
  end

  def refresh_token_if_needed!
    return if @user.fitness_app_token_expires_at.present? && @user.fitness_app_token_expires_at.future?

    force_refresh_token!
  end

  def force_refresh_token!
    @connection = nil

    new_token = OAuth2::AccessToken.new(
      self.class.oauth_client(@provider),
      @user.fitness_app_access_token,
      refresh_token: @user.fitness_app_refresh_token
    ).refresh!

    @user.update!(
      fitness_app_access_token: new_token.token,
      fitness_app_refresh_token: new_token.refresh_token,
      fitness_app_token_expires_at: Time.at(new_token.expires_at)
    )
  rescue OAuth2::Error => e
    Rails.logger.error("Fitness app token refresh failed for user #{@user.id} (#{@provider}): #{e.message}")
    @user.update!(fitness_app_access_token: nil, fitness_app_refresh_token: nil,
                  fitness_app_token_expires_at: nil)
    raise TokenRefreshError, "Token refresh failed — please reconnect your fitness app."
  end

  def connection
    @connection ||= Faraday.new(url: API_BASE) do |f|
      f.headers["Authorization"] = "Bearer #{@user.fitness_app_access_token}"
      f.headers["Accept"] = "application/json"
    end
  end
end
