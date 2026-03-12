# config/routes.rb
Rails.application.routes.draw do
  root "dashboard#index"

  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get "steps/report", to: "steps#report", as: :steps_report

  resources :steps, only: [ :update ] do
    member do
      patch :admin_update
    end
  end

  resources :milestones, only: [] do
    resource :pin, only: [ :new, :create ], controller: "milestone_pins"
  end
  get "milestone_pin/dismiss", to: "milestone_pins#dismiss", as: :dismiss_milestone_popup

  get "auth/fitbit/callback", to: "fitbit#callback", as: :fitbit_callback
  get "auth/fitbit", to: "fitbit#connect", as: :fitbit_connect
  delete "auth/fitbit", to: "fitbit#disconnect", as: :fitbit_disconnect

  # Health check for deployment
  get "up", to: "rails/health#show", as: :rails_health_check
end
