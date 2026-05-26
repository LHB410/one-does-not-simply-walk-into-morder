class FitnessAppConnectionsController < ApplicationController
  before_action :require_login
  before_action :set_provider

  def connect
    state = SecureRandom.hex(16)
    session[:fitness_app_oauth_state] = state
    session[:fitness_app_timezone] = params[:timezone]

    redirect_to FitnessAppClient.authorize_url(
      redirect_uri: fitness_app_callback_url(provider: @provider),
      state: state,
      provider: @provider
    ), allow_other_host: true
  end

  def callback
    if params[:state] != session.delete(:fitness_app_oauth_state)
      return redirect_to root_path, alert: "Invalid OAuth state"
    end

    token = FitnessAppClient.exchange_code(
      code: params[:code],
      redirect_uri: fitness_app_callback_url(provider: @provider),
      provider: @provider
    )

    current_user.update!(
      fitness_app_provider: @provider,
      fitness_app_uid: token.params["user_id"],
      fitness_app_access_token: token.token,
      fitness_app_refresh_token: token.refresh_token,
      fitness_app_token_expires_at: Time.at(token.expires_at),
      timezone: session.delete(:fitness_app_timezone)
    )

    FitnessAppSyncJob.schedule_for(current_user)

    redirect_to root_path, notice: "#{@provider.titleize} connected!"
  rescue OAuth2::Error => e
    Rails.logger.error("Fitness app OAuth failed (#{@provider}): #{e.message}")
    redirect_to root_path, alert: "Failed to connect #{@provider.titleize}"
  end

  def disconnect
    current_user.update!(
      fitness_app_provider: nil,
      fitness_app_uid: nil,
      fitness_app_access_token: nil,
      fitness_app_refresh_token: nil,
      fitness_app_token_expires_at: nil,
      fitness_app_last_sync_at: nil
    )

    redirect_to root_path, notice: "Fitness app disconnected"
  end

  private

  def set_provider
    @provider = params[:provider]
    prefix = @provider.upcase
    unless ENV.key?("#{prefix}_CLIENT_ID")
      redirect_to root_path, alert: "Unknown fitness app provider"
    end
  end
end
