Rails.application.routes.draw do
  # Sidekiq Web UI
  require 'sidekiq/web'
  mount Sidekiq::Web => '/sidekiq'
  
  # Admin context for AdminUsers (technical/system admin)
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  
  # User context for family management  
  devise_for :users, ActiveAdmin::Devise.config.merge(path: 'family')
  
  # Family admin namespace routes
  namespace :family do
    ActiveAdmin.routes(self)
    get 'job_status', to: 'job_status#index'
  end
  
  # Image serving routes
  resources :images, only: [:show]
  get 'thumbnails/:id', to: 'images#thumbnail', as: 'thumbnail'
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
