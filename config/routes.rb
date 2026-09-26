# frozen_string_literal: true

Rails.application.routes.draw do
  get '/clubhouse', to: 'clubhouse/pages#show', as: :clubhouse
  get '/clubhouse/setup', to: 'clubhouse/pages#setup', as: :clubhouse_setup
  post '/clubhouse/import', to: 'clubhouse/pages#import', as: :clubhouse_import
  get '/clubhouse/api/league', to: 'clubhouse/league#show'
  post '/clubhouse/api/league', to: 'clubhouse/league#update'
  get '/clubhouse/api/photos', to: 'clubhouse/photos#index'
  post '/clubhouse/api/photos', to: 'clubhouse/photos#create'
  delete '/clubhouse/api/photos', to: 'clubhouse/photos#destroy'

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get 'up' => 'rails/health#show', as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  get 'manifest' => 'rails/pwa#manifest', as: :pwa_manifest
  get 'service-worker' => 'rails/pwa#service_worker', as: :pwa_service_worker

  resources :seasons, only: %i[index]

  get    'auth/google_oauth2/callback', to: 'sessions#create'
  get    'auth/failure', to: 'sessions#failure'
  delete 'sign_out', to: 'sessions#destroy', as: :sign_out
  resource :profile, only: %i[show]

  namespace :admin do
    resources :players, only: %i[index new create edit update]
  end

  # Defines the root path route ("/")
  root 'home#index'
end
