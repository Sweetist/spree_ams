module Spree::Order::BalanceAndCredit
  extend ActiveSupport::Concern

  included do
    has_many :balance_transactions, as: :originator,
                                    class_name: 'Spree::BalanceTransaction'
    has_many :credit_transactions, as: :originator,
                                   class_name: 'Spree::CreditTransaction'
  end

  def move_balance_and_credit
    return unless States[state] >= States['approved'] && total_changed?

    account.move_balance_amount(total - total_was, self)
    account.move_credit_amount(total_was - total, self) if payment_total > total
  end

  def not_right_balance?
    return false unless approved?
    return false if States[state] < States['approved']
    return false if payment_total == total
    return false if balance_transactions.sum(:amount) == total - payment_total

    true
  end

  def move_balance_to_consistence
    account.move_balance_amount(total - payment_total, self)
  end

  def errors_from_account_balance
    return [] if account.credit_limit.blank?
    return [] if account.credit_limit >= total + account.balance

    [Spree.t('errors.balance_more_than_credit_limit')]
  end
end
