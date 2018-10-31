Rails.application.routes.draw do
  require 'sidekiq/web'

  constraints CustomDomainConstraint do
  root to: 'static_pages#root'

  mount Spree::Core::Engine, at: '/'
  mount Commontator::Engine => '/commontator'
  get '/getsweet-info', to: redirect('https://goo.gl/BY9B3b'), as: :getsweet

  Spree::Core::Engine.add_routes do
    scope module: 'cust' do
      get '/getsweet-info', to: redirect('https://goo.gl/BY9B3b'), as: :getsweet
      get :save_and_clear_order, to: 'orders#save_and_clear_order'
      get :update_customized_pricing, to: 'products#update_customized_pricing'
      get :request_access, to: 'request_access#request_access'
      post :request_access, to: 'request_access#request_access'
      post :submit_request, to: 'request_access#submit_request'
      get :user_details, to: 'request_access#user_details'

      resources :accounts, only: [:show, :edit, :update, :index] do
        post :payments
        post :user_accounts
        resources :users, only: [:new, :create, :destroy]
        resources :addresses
        patch :update_default_address, on: :member
        collection do
          get :update_states
        end
      end
      resource :my_company, controller: 'companies', only: [:show, :edit, :update] do
        get :update_states

        resources :users do
          get :update_account_access, on: :member
          patch :update_account_access, on: :member
        end

        resources :company_images, except: [:show] do

          collection do
            post :update_positions
          end
          get :display_image, on: :member
        end
      end
      resource :my_profile, controller: :users, only: [:edit, :update, :destroy] do
        resources :user_images, except: [:show] do
          collection do
            post :update_positions
          end
        end
        patch :update_password, on: :member
      end

      resources :vendors, path: 'shop', only: [:index, :show] do
        resources :products, only: [:index, :show] do
          resources :variants, only: [:show] do
            member do
              get :similar_products
            end
          end
        end
      end
      resources :messages, only: [:new, :create]

      resources :orders do
        get :generate
        get :user_accounts, on: :collection
        get :set_ship_address_on_new, on: :collection
        post :credit_card_create
        resources :payments
        get :update_delivery_date, on: :member
      end

      resources :orders, :except => [:index, :new, :create, :destroy] do
        post :populate, :on => :collection
        post :add_to_cart, to: 'orders#add_to_cart'
        get :unpopulate, to: 'orders#unpopulate'
        get :success, on: :member
        get :variant, on: :member
        post :recalculate_shipping
        get :set_ship_address
        get :new_ship_address
        get :new_bill_address
        post :create_and_assign_ship_address
        post :edit_bill_address
        post :create_bill_address
        # resource :receiving, only: [:show, :edit, :update]
      end

      resources :standing_orders do
        post :generate
        get :user_accounts, on: :collection
        resources :products, controller: "standing_order_products" do
          resources :variants, only: :show
        end
        get :unpopulate, on: :member
      end

      resources :standing_order_schedules do
        put :skip
        put :enque
        put :generate_order
        put :process_order
        put :remind
      end

      resources :receivings, only: [:index, :edit, :update]
      resources :invoices, only: [:index, :show, :edit, :update]
      resources :credit_cards, only: :destroy

      populate_redirect = redirect do |params, request|
        request.flash[:error] = Spree.t(:populate_get_error)
        request.referer || '/cart'
      end

      get '/orders/populate', :to => populate_redirect
    end

    namespace :manage do
      get :save_and_clear_order, to: 'orders#save_and_clear_order'

      resources :messages, only: [:new, :create]

      post :dt_orders, constraints: { format: 'json' }, to: 'orders#index'
      post :dt_po_orders, constraints: { format: 'json' },
                          to: 'purchase_orders#index'
      post :dt_account_payments, constraints: { format: 'json' },
                                 to: 'account_payments#index'
      post :dt_credit_memos, constraints: { format: 'json' },
                             to: 'credit_memos#index'
      namespace :datatable_settings do
        get :load_state
        post :save_state
      end

      resources :forms do
        get :preview, on: :collection
      end

      resources :promotions, path: :pricing_adjustments
      resources :promotion_categories, path: :pricing_adjustment_categories
      resources :price_lists do
        collection do
          get :add_account
          get :accounts_by_type
          get :add_variant
          get :variants_by_category
        end
        member do
          post :clone
        end
      end

      scope :configuration do

        resources :order_rules do
          put :toggle_active, on: :member
        end

        resource  :customer_viewable_attribute,
                  path: :customer_view_settings,
                  only: [:show, :edit, :update]
        resource :carriers, only: %i[show update edit]
        resources :pages do
          collection do
            post :update_positions
          end
        end
        resources :stock_locations
        resources :shipping_categories
        resources :shipping_methods
        resources :tax_rates
        resources :tax_categories
        resources :payment_terms, only: :index
        resources :payment_methods
        resource  :invoice_settings,
                  path: :order_invoice_settings,
                  only: [:show, :edit, :update]
        resource  :outgoing_communications, only: [:edit, :update] do
          post :update_mail_to_settings
        end
        resources :zones do
          get :load_members, on: :collection
        end
        resources :cities, only: [:new, :create]
      end

      resources :email_templates, only: [:edit, :update] do
        post :restore_template
        get :preview_mailer
      end
      get '/email_templates', to: redirect('/manage/configuration/outgoing_communications/edit')

      resources :option_types

      resources :taxons, path: :categories
      resources :reps
      resources :customer_types
      resource  :inventory, only: :show do
        get :load_assembly, on: :collection
        get :download_csv
      end
      resources :stock_transfers do
        get :current_stock, on: :collection
        get :create_lot, on: :collection
        post :build_inventory, on: :collection
      end

      resources :lots do
        patch :actions_router, on: :collection, to: 'lots#actions_router'
        member do
          post :archive
          post :unarchive
        end
      end
      resources :stock_item_lots#, only: [:create]

      resource :account, controller: 'companies', only: [:show, :edit, :update] do
        get :update_states
        post :colors
        delete :delete_data
        post :reset_inventory
        resources :users do
          resources :user_images, except: [:show] do
            collection do
              post :update_positions
            end
          end
          member do
            patch :update_comm_settings
            patch :update_password
            patch :update_permissions
            get :toggle_permissions
          end
        end
        resources :account_images, controller: 'company_images', except: [:show] do
          collection do
            post :update_positions
          end
          get :display_image, on: :member
        end
        resources :logos, controller: 'company_logos', except: [:show] do
          collection do
            post :update_positions
          end
        end
        resources :banner_images, controller: 'banner_images', except: [:show] do
          collection do
            post :update_positions
          end
        end
        resources :contacts do
          patch :actions_router, on: :collection, to: 'contacts#actions_router'
          get :invite_email, on: :member
          get :download_csv, on: :collection
          patch :mark_invited, on: :member
        end
      end

      resources :customers, only: [:new, :index] do
        patch :actions_router, on: :collection, to: 'customers#actions_router'
        get :invite_email, on: :member
        collection do
          get :update_states
          get :download_csv
          resources :accounts, only: [:new, :create, :index]
        end
        resources :accounts, except: [:new, :create, :index] do
          resources :addresses
          patch :update_default_address, on: :member
          get :promotions, on: :member
          get :activate, on: :member
          get :deactivate, on: :member
          patch :update_primary_contact, on: :member
          post :create_new_contact, on: :member
          post :delete_contact, on: :member
         end
      end

      # route for vendors
      resources :vendors, only: [:new, :index] do
        patch :actions_router, on: :collection, to: 'customers#actions_router'
        resources :ship_addresses
        resources :vendor_users, only: [:new, :create]
        get :invite_email, on: :member
        collection do
          get :update_states
          resources :vendor_accounts, only: [:new, :create, :index]
        end
        resources :vendor_accounts, except: [:new, :create, :index] do
          get :new_user, on: :member
          post :create_user, on: :member
          get :create_user, on: :member
          post :create_new_contact, on: :member
          post :existing_user, on: :member
          get :activate, on: :member
          get :deactivate, on: :member
        end
      end

      resources :reimbursement_types, only: [:index]
      resources :refund_reasons, except: [:show, :destroy]
      resources :return_authorization_reasons, except: [:show, :destroy]

      resources :orders do
        resources :bookkeeping_documents, only: :index # pdf invoices
        patch :actions_router, on: :collection, to: 'orders#actions_router'
        resources :adjustments, except: [:index, :show]
        get :get_lot_qty, on: :member
        post :create_lot, on: :collection

        collection do
          get :submit_lot_count
          get :collate_bills_of_lading
          get :collate_packing_slips
          get :collate_selected_invoice
          get :download_csv
          get :download_xlsx
          patch :customer_accounts
          get :variant_search
          get :update_order_line_items_position
          get :payment_states
        end

        member do
          post :add_line_item
          post :void
          get :resend_email
          get :send_invoice
          post :mark_paid
          post :mark_unpaid
          post :add_to_lot
          post :recalculate_shipping
          post :allocate_stock
          get :set_ship_address
          get :new_ship_address
          get :new_bill_address
          post :create_and_assign_ship_address
          post :edit_bill_address
          post :create_bill_address
        end


        resources :shipments do
          patch :update_all, on: :collection
        end

        get :generate
        post :unapprove
        collection do
          get :daily_packing_slips
          get :daily_bills_of_lading
        end

        resources :payments do
          member do
            post :fire
          end

          resources :log_entries
          resources :refunds, only: [:new, :create, :edit, :update]
        end
        resources :reimbursements, only: [:index, :create, :show, :edit, :update] do
          member do
            post :perform
          end
        end
        resources :customer_returns, only: [:index, :new, :edit, :create, :update] do
          member do
            put :refund
          end
        end
        resources :return_authorizations do
          member do
            put :fire
          end
        end
      end

      resources :return_items, only: [:update]

      resources :bookkeeping_documents, only: [:index, :show]

      resources :credit_memos do
        collection do
          get :variant_search
          post :update_credit_memo_line_items_position
          get :customer_accounts
        end
        member do
          post :add_line_item
          post :unpopulate
        end
      end

      resources :orders, :except => [:index, :new, :create, :destroy] do
        post :populate, :on => :collection
        post :add_to_cart, to: 'orders#add_to_cart'
        get :unpopulate, to: 'orders#unpopulate'
      end

      resources :account_payments do
        collection do
          get :vendor_accounts
          get :new_payment
        end
        member do
          put :fire
          get :new_refund
          put :create_refund
        end
      end

      # route for purchase orders
      resources :purchase_orders do
        resources :shipments, only: :index
        resources :bookkeeping_documents, only: :index # pdf invoices
        patch :actions_router, on: :collection, to: 'orders#actions_router'

        get :get_lot_qty, on: :member
        post :create_lot, on: :collection
        post :submit_lot_count, on: :collection

        get :vendor_accounts, on: :collection
        get :variant_search, on: :collection
        get :receive_at, on: :collection
        post :add_line_item, on: :member
        get :resend_email, on: :member

        post :populate, :on => :collection
        post :add_to_cart, to: 'orders#add_to_cart'
        get :unpopulate, on: :member
        post :void, on: :member
      end

      resources :standing_orders do
        post :generate
        post :clone
        get :update_line_items_position, on: :collection
        resources :products, controller: "standing_order_products" do
          resources :variants, only: [:show, :edit]
        end
        get :customer_accounts, on: :collection
        get :variant_search, on: :collection
        post :add_line_item, on: :member
        get :unpopulate, on: :member
      end

      resources :standing_order_schedules do
        put :skip
        put :enque
        put :generate_order
        put :process_order
        put :remind
      end

      scope :reports do
        resource :production, only: :show do
          get :download_xlsx
        end
        get :production_by_customer, to: 'productions#by_customer'
        resource :packing_list, only: :show do
          get :download_xlsx
        end
        resource :customers_report, only: :show
        resource :total_sales_report, only: :show
        resource :products_report, only: :show
        get :inventory_detail_report, to: 'inventory_reports#detail_report'
        get :inventory_summary_report, to: 'inventory_reports#summary_report'
        get :inventory_download_csv, to: 'inventory_reports#download_csv'
      end

      resources :invoices do
        resources :bookkeeping_documents, only: :index # pdf invoices
        member do
          post :void
          get :separate_invoice
          get :send_invoice
          post :mark_paid
          post :mark_unpaid
        end

        patch :actions_router, on: :collection, to: 'invoices#actions_router'
        collection do
          get :daily
          get :collate_invoices
          get :payment_states
        end
      end
      get :daily_invoices, to: 'invoices#daily_invoices'
      resources :packaging_slip, only: :show
      resources :bill_of_lading, only: :show

      populate_redirect = redirect do |params, request|
        request.flash[:error] = Spree.t(:populate_get_error)
        request.referer || '/cart'
      end

      get '/orders/populate', :to => populate_redirect
      post :update_all_viewable_variants, to: 'products#update_all_viewable_variants'
      get :update_customized_pricing, to: 'products#update_customized_pricing'

      resources :products do
        resources :images do
          collection do
            post :update_positions
          end
        end
        get :create_lot, on: :collection
        get :get_lot_info, on: :collection
        patch :actions_router, on: :collection, to: 'products#actions_router'
        get :destroy_variant, to: 'products#destroy_variant'

        resources :variants do
          member do
            post :discontinue
            post :make_available
          end
        end
      end

      resources :variants do
        member do
          post :add_part_to_assembly
          get :load_parts_variants
          patch :toggle_lot_tracking
          post :discontinue
          post :make_available
        end
      end

      resources :shipping_groups
      resources :permission_groups

      resources :integrations do
        get :execute
        get :enqueue
        get :enqueue_variants
        get :fetch_products
        get :fetch_customers
        get :fetch_orders
        get :fetch_credit_memos
        get :fetch_account_payments
        get :toggle_skipped_actions
        post :kill

        resources :integration_actions, only: :destroy do
          collection do
            delete :destroy_successful
            delete :destroy_all
          end
        end
      end

      resources :credit_cards, only: :destroy

      resources :product_imports do
        post :verify
        post :import
      end
      resources :customer_imports do
        post :verify
        post :import
      end
      resources :vendor_imports do
        post :verify
        post :import
      end
      scope :configuration do
        resources :chart_accounts
        resources :transaction_classes
      end
      #end

      # get '/', to: 'root#index'#, as: :admin
      get '/', to: 'root#overview'
      post '/', to: 'root#overview'
    end

  # end

    # QuickBooks Desktop -- Web Connector *.qwc file download route
    get 'quickbooks/qwc'

    namespace :admin do
      # resources :cities, :only => :index
      resources :countries do
        resources :states do
          resources :cities do
          end
        end
      end

      constraint = lambda { |request| request.env["warden"].authenticate? and request.env['warden'].user.is_admin? }
      constraints constraint do
        mount Sidekiq::Web => '/sidekiq'
      end

      get '/search/companies', to: "search#companies", as: :search_companies

      resources :orders do
        member do
          patch :delivery_update
          #resources :print_invoice, only: [:index, :show]
        end
        resources :order_versions, only: [:index, :show]
      end

      resources :companies do
        resources :company_images do
          collection do
            post :update_positions
          end
        end
        resources :company_logos do
          collection do
            post :update_positions
          end
        end
        get :reset_email_templates
        get :setup_email_templates
        member do
          get :customer_accounts
          get :vendor_accounts
          get :users
          post :load_default_data
          post :load_sample_data
          post :reset_inventory
        end
      end

      resources :accounts

      resources :users do
        resources :user_images
      end

      resources :payment_terms

    end

    namespace :api, defaults: { format: 'json' } do

      resources :customers
      resources :accounts
      resources :customer_types
      resources :reps
      resources :payment_terms
      resources :integrations, only: [] do
        post :order_status
        match :execute, via: [:get, :post], defaults: { format: 'xml' }
      end
    end

    # signup controller
    resource :sign_up

  end

end
end
