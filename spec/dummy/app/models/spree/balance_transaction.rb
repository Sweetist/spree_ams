class Spree::BalanceTransaction < ActiveRecord::Base
  belongs_to :originator, polymorphic: true
  belongs_to :account
  validates :account, :originator, :amount, presence: true
end
