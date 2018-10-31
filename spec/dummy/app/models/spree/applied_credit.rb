# == Schema Information
#
# Table name: spree_applied_credits
#
#  id                 :integer          not null, primary key
#  credit_memo_id     :integer
#  account_payment_id :integer
#  amount             :decimal(15, 5)   default(0), not null
#  created_at         :datetime         not null
#  updated_at         :datetime         not null
#

class Spree::AppliedCredit < ActiveRecord::Base
  belongs_to :credit_memo
  belongs_to :account_payment

  validates :credit_memo, :account_payment, presence: true

  after_create :update_credit_memo_remaining

  def update_credit_memo_remaining
    return unless credit_memo

    credit_memo.persist_totals
  end
end
