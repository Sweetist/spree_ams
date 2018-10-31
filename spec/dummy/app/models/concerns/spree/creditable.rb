module Spree
  module Creditable
    extend ActiveSupport::Concern

    included do
      has_many :credit_transactions, dependent: :destroy
      validates_numericality_of :available_credit,
                                greater_than_or_equal_to: 0,
                                message: Spree.t('errors.less_than_zero')
    end

    def move_credit_amount(current_amount, originator, use_credit = false)
      return if current_amount.zero?
      credit_transactions.create(amount: current_amount,
                                 originator: originator,
                                 use_credit: use_credit)
      update!(available_credit: available_credit + current_amount)
    end
  end
end
