Rails.application.routes.draw do
  devise_for :users

  root to: 'spa#index'

  namespace :api do
    get 'test', to: 'test#index'
    get 'me', to: 'sessions#me'

    resources :folders, only: %i[index show create update destroy]
    resources :downloads, only: %i[index show create destroy] do
      member do
        get :file
      end
    end
  end

  get '*path', to: 'spa#index', constraints: ->(req) { !req.xhr? && req.format.html? }
end
