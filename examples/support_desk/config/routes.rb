SupportDesk::Engine.routes.draw do
  root "conversations#index"
  post "/session", to: "sessions#create"
  delete "/session", to: "sessions#destroy"
  resources :conversations, only: [ :show ] do
    member do
      post :stream
      get :snapshot
      patch :state
    end
  end
end
