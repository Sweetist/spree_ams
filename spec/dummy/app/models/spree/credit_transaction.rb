# == Schema Information
#
# Table name: spree_credit_transactions
#
#  id              :integer          not null, primary key
#  use_credit      :boolean          default(FALSE)
#  account_id      :integer          not null
#  amount          :decimal(15, 5)   default(0), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  originator_id   :integer
#  originator_type :string
#

class Spree::CreditTransaction < ActiveRecord::Base
  belongs_to :originator, polymorphic: true
  belongs_to :account
  validates :account, :originator, :amount, presence: true
end
