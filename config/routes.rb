Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root :to => 'home#index'

  resources :uploads, only: [:new, :create]

  get '/debug/env'
  get '/debug/db'
  get '/debug/trigger_error'
  get '/debug/build_info'
  get '/debug/instance_id'
  get '/debug/sleep/:seconds', to: 'debug#debug_sleep', constraints: { seconds: /.*/ }
  get '/debug/stress/:seconds', to: 'debug#stress', constraints: { seconds: /.*/ }  
  match '/debug/request' => 'debug#debug_request', via: :all  
end
