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

  # Health check for Heroku
  get "up", to: "rails/health#show", as: :rails_health_check
end
