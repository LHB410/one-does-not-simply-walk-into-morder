Rails.application.routes.draw do
  root "dashboard#index"

  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  resources :steps, only: [ :index, :update ] do
    member do
      patch :admin_update
    end
  end

  # Health check for Heroku
  get "up", to: "rails/health#show", as: :rails_health_check
end
