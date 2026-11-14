Rails.application.routes.draw do
  root "recipes#new"
  resources :recipes, only: :index

  # Returns 200 when the app boots with no exceptions; used by uptime monitors.
  get "up" => "rails/health#show", as: :rails_health_check
end
