module Spree
  module Balancable
    extend ActiveSupport::Concern

    included do
      has_many :balance_transactions, dependent: :destroy
    end

    def move_balance_amount(amount, originator)
      return if amount.zero?
      balance_transactions.create(amount: amount,
                                  originator: originator)
      update!(balance: balance + amount)
    end

    def initial_orders_balance
      orders.select(&:not_right_balance?).each do |order|
        next if order.balance_transactions.any?
        order.move_balance_to_consistence
      end
    end
  end
end
