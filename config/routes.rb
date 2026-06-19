# config/routes.rb
Rails.application.routes.draw do
  root "dashboard#index"

  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"
  patch "account", to: "accounts#update", as: :account
  delete "account", to: "accounts#destroy"

  get "sign_up", to: "registrations#new", as: :sign_up, format: false
  post "sign_up", to: "registrations#create"

  get "privacy", to: "pages#privacy", as: :privacy, format: false
  get "terms", to: "pages#terms", as: :terms, format: false

  patch "group/password", to: "groups#update_password", as: :group_password

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

  get "auth/health/callback", to: "health#callback", as: :health_callback
  get "auth/health", to: "health#connect", as: :health_connect
  delete "auth/health", to: "health#disconnect", as: :health_disconnect

  # Health check for deployment
  get "up", to: "rails/health#show", as: :rails_health_check
end
