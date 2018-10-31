# == Schema Information
#
# Table name: spree_user_accounts
#
#  id         :integer          not null, primary key
#  account_id :integer          not null
#  user_id    :integer          not null
#  created_at :datetime
#  updated_at :datetime
#

module Spree
  class Spree::UserAccount < Spree::Base
    validates :user_id, :account_id, presence: true
    validates :user_id, uniqueness: {scope: :account_id, message: 'already has access to the selected account'}
    belongs_to :user, class_name: 'Spree::User', foreign_key: :user_id, primary_key: :id
    belongs_to :account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id
  end
end
