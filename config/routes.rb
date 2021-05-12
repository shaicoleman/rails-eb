Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root :to => 'home#index'

  resources :uploads, only: [:new, :create]

  get '/debug/trigger_error'
  match '/debug/request' => 'debug#debug_request', via: :all  
end
