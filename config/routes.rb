Rails.application.routes.draw do
  devise_for :users

  # Root
  root 'pages#home'

  # Dashboard
  get 'dashboard', to: 'dashboard#show'

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

  # Admin
  namespace :admin do
    get 'dashboard', to: 'dashboard#show'
    resources :therapist_applications, only: [:index, :show] do
      member do
        post :approve
        post :reject
      end
    end
  end
end
