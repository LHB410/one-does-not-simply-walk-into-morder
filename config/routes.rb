# config/routes.rb
Rails.application.routes.draw do
  root "dashboard#index"

  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  get "steps/report", to: "steps#report", as: :steps_report
  get "steps/stats", to: "steps#stats", as: :steps_stats

  resources :steps, only: [ :update ] do
    member do
      patch :admin_update
    end
  end

  resources :milestones, only: [] do
    resource :pin, only: [ :new, :create ], controller: "milestone_pins"
  end
  get "milestone_pin/dismiss", to: "milestone_pins#dismiss", as: :dismiss_milestone_popup

  get "auth/:provider/callback", to: "fitness_app_connections#callback", as: :fitness_app_callback
  get "auth/:provider", to: "fitness_app_connections#connect", as: :fitness_app_connect
  delete "auth/:provider", to: "fitness_app_connections#disconnect", as: :fitness_app_disconnect

  # Health check for deployment
  get "up", to: "rails/health#show", as: :rails_health_check
end
