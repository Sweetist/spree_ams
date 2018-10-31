# == Schema Information
#
# Table name: spree_notes
#
#  id         :integer          not null, primary key
#  body       :text
#  created_at :datetime
#  updated_at :datetime
#  account_id :integer          not null
#

module Spree
	class Note < Spree::Base
    # validates :user_id, presence: true

    belongs_to :order, class_name: 'Spree::Order', foreign_key: :order_id, primary_key: :id

  end
end
