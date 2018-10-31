module Spree
  class AccountPayment
    class GatewayOptions
      def initialize(account_payment)
        @account_payment = account_payment
      end

      def email
        @account_payment.account.email
      end

      def customer
        @account_payment.customer.email
      end

      def customer_id
        @account_payment.customer.id
      end

      def ip
        @account_payment.last_ip_address
      end

      def order_id
        @account_payment.display_number.to_s
      end

      def shipping
        0
      end

      def tax
        0
      end

      def subtotal
        @account_payment.amount
      end

      def discount
        0
      end

      def currency
        @account_payment.currency
      end

      def billing_address
        @account_payment.account.bill_address.try(:active_merchant_hash)
      end

      def shipping_address
        @account_payment.account.default_ship_address.try(:active_merchant_hash)
      end

      def hash_methods
        %i[email customer customer_id ip order_id shipping tax
           subtotal discount currency billing_address shipping_address]
      end

      def to_hash
        Hash[hash_methods.map do |method|
          [method, send(method)]
        end]
      end
    end
  end
end
