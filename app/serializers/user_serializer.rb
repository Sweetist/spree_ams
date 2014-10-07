class UserSerializer < ActiveModel::Serializer
  embed :ids, include: true

  attributes  :id,
              :email,
              :remember_token,
              :persistence_token,
              :reset_password_token,
              :perishable_token,
              :sign_in_count,
              :failed_attempts,
              :last_request_at,
              :current_sign_in_at,
              :login,
              :authentication_token,
              :unlock_token,
              :locked_at,
              :reset_password_sent_at,
              :created_at,
              :updated_at,
              :spree_api_key,
              :remember_created_at

  # has_one :current_order, root: :orders, embed_key: :number, serializer: OrderSerializer
  # has_one :ship_address
  # has_one :bill_address

  # def current_order
  #   # TODO this also will return Completed Orders
  #   object.orders.last
  # end

end