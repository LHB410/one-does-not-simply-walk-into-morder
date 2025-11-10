# app/controllers/sessions_controller.rb
class SessionsController < ApplicationController
  def create
    credentials = params[:session] || params
    email = credentials[:email]
    password = credentials[:password]
    user = User.find_by(email: email)
    if user&.authenticate(password)
      session[:user_id] = user.id
      respond_to do |format|
        # Force a full page visit so content conditioned on logged_in? re-renders
        format.html { redirect_to root_path, turbo: false }
        format.turbo_stream { redirect_to root_path, status: :see_other }
      end
    else
      respond_to do |format|
        format.html {
          redirect_to root_path, alert: "Invalid email or password"
        }
        format.turbo_stream {
          render turbo_stream: turbo_stream.replace(
            "login-error",
            partial: "sessions/error",
            locals: { error: "Invalid email or password" }
          ), status: :unprocessable_entity
        }
      end
    end
  end

  def destroy
    session[:user_id] = nil
    redirect_to root_path
  end
end
