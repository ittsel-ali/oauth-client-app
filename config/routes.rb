Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html

    resources :oauth do 
      collection do
        post :auth
        get :callback
        post :get_campaign_info
        post :refresh_token
      end
    end

    root "oauth#new"
end
