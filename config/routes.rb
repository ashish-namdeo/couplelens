Rails.application.routes.draw do
  devise_for :users, controllers: {
    sessions: "users/sessions",
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # Root
  root 'pages#home'

  # Dashboard
  get 'dashboard', to: 'dashboard#show'
  post 'dashboard/generate_bot_link_code', to: 'dashboard#generate_bot_link_code', as: :generate_bot_link_code
  post 'dashboard/send_link_invitation', to: 'dashboard#send_link_invitation', as: :send_link_invitation
  post 'dashboard/generate_telegram_link', to: 'dashboard#generate_telegram_link', as: :generate_telegram_link
  delete 'dashboard/unlink_bot', to: 'dashboard#unlink_bot', as: :unlink_bot

  # AI Relationship Assistant
  resources :conversations, only: [:index, :show, :new, :create, :destroy] do
    resources :messages, only: [:create]
  end

  # AI Conflict Mediator
  resources :conflict_sessions do
    member do
      post :analyze
    end
  end

  # AI Conversation Rewrite Tool
  get 'rewrite', to: 'rewrite_tool#index'
  post 'rewrite', to: 'rewrite_tool#rewrite'

  # Health Dashboard
  get 'health', to: 'health_dashboard#show'
  post 'health/calculate', to: 'health_dashboard#calculate', as: :calculate_health

  # Compatibility Assessment
  resources :compatibility_assessments, only: [:index, :show, :new, :create]

  # Therapist Marketplace
  resources :therapists, only: [:index, :show]

  # Bookings
  resources :bookings, only: [:index, :create] do
    member do
      patch :cancel
    end
  end

  # Financial Tools
  resources :expenses, only: [:index, :create, :destroy]

  # Memory Timeline
  resources :memories, only: [:index, :new, :create, :destroy]

  # Growth Programs
  resources :programs, only: [:index, :show] do
    member do
      post :enroll
    end
  end

  # Workshops & Retreats
  resources :workshops, only: [:index, :show] do
    member do
      post :register
    end
  end

  # Therapist Application (public)
  resources :therapist_applications, only: [:new, :create]

  # Therapist Registration (signup + apply in one step)
  get 'therapist_signup', to: 'therapist_registrations#new', as: :therapist_registration
  post 'therapist_signup', to: 'therapist_registrations#create'

  # Therapist Portal
  namespace :therapist do
    get 'dashboard', to: 'dashboard#show'
    resource :profile, only: [:edit, :update]
  end

  # Admin
  namespace :admin do
    get 'dashboard', to: 'dashboard#show'
    get 'messaging_setup', to: 'messaging_setup#show'
    post 'messaging_setup/set_telegram_webhook', to: 'messaging_setup#set_telegram_webhook', as: :set_telegram_webhook
    get 'messaging_setup/telegram_webhook_info', to: 'messaging_setup#telegram_webhook_info', as: :telegram_webhook_info
    resources :therapist_applications, only: [:index, :show] do
      member do
        post :approve
        post :reject
      end
    end
  end

  # Messaging Platform Webhooks (API)
  namespace :api do
    namespace :v1 do
      # Telegram
      post 'webhooks/telegram/:token', to: 'telegram_webhook#receive', as: :telegram_webhook

      # WhatsApp
      get  'webhooks/whatsapp', to: 'whatsapp_webhook#verify'
      post 'webhooks/whatsapp', to: 'whatsapp_webhook#receive'
    end
  end
end
