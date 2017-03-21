Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html

  # Serve websocket cable requests in-process
  mount ActionCable.server => "/cable"

  post "/login", to: "sessions#create"
  get "/token-login", to: "tokens#consume"
  root "tokens#show"

  # get "/users/:id", to: "users#show"
  resources :users, only: [:show]
end
