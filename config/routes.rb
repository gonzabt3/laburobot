Rails.application.routes.draw do
  get 'hello_world', to: 'hello_world#index'
  # Health check
  get "up" => "rails/health#show", as: :rails_health_check

  # Telegram webhook
  namespace :telegram do
    post "webhook", to: "webhooks#create"
  end

  # WhatsApp webhook
  namespace :whatsapp do
    get  "webhook", to: "webhooks#show"   # verification challenge
    post "webhook", to: "webhooks#create" # incoming messages
  end

  # Admin panel (protected by HTTP basic auth)
  namespace :admin do
    root to: "dashboard#index"
    resources :provider_profiles, only: [ :index ] do
      member { patch :toggle_active }
    end
    resources :reports, only: [ :index, :update ]
  end

  # Root redirects to admin for now
  root to: redirect("/admin")
end
