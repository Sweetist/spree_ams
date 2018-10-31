Spree::Core::Engine.routes.draw do
  namespace :api do
    namespace :ams do
      match '*path' => 'cors#preflight_check', via: [:options]

      resources :products
      resources :line_items
      resources :orders do
        member do
          put :cancel
          # put :empty
          # put :apply_coupon_code
        end
      end
      resources :taxonomies
      resources :taxons
      resources :countries, :only => [:index, :show]

      # Order Routes Concern?
      resources :checkouts, only: [:update] do
        member do
          put :next
        end
      end
      resources :customers
      resources :users do
        collection do
          post 'token'
        end
      end
    end
  end
end
