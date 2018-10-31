module Spree
  class AccountPaymentMethod < Spree::Base

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod', foreign_key: :payment_method_id, primary_key: :id
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id

  end
end
