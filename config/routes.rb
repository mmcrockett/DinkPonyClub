# frozen_string_literal: true

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker

  resources :seasons, only: %i[index]
  resources :matches, only: %i[show edit update]
  resources :players, only: %i[index show]
  get 'standings', to: 'standings#show', as: :standings

  get 'schedule.ics', to: 'calendars#show', as: :schedule_calendar, format: false, defaults: { format: :ics }
  resources :match_nights, only: %i[index show], path: 'schedule' do
    resource :availability, only: %i[update]
    patch 'availability/:player_id', to: 'availabilities#update_for_player', as: :player_availability
  end

  get    'auth/google_oauth2/callback', to: 'sessions#create'
  get    'auth/failure', to: 'sessions#failure'
  get    'test/sign_in/:player_id', to: 'test_sessions#create', as: :test_sign_in if Rails.env.test?
  delete 'sign_out', to: 'sessions#destroy', as: :sign_out
  get    'sign_in', to: 'sessions#new', as: :sign_in
  resource :magic_link, only: %i[create show], path: 'sign_in/link' do
    post :redeem
  end
  resource :profile, only: %i[show] do
    resource :calendar_token, only: %i[create]
  end

  namespace :admin do
    resources :players, only: %i[index new create edit update] do
      resource :charges, only: %i[update]
    end
    resources :fees, only: %i[index create destroy]
    resource :roster, only: %i[show update]
  end

  # Defines the root path route ("/")
  root 'home#index'
end
