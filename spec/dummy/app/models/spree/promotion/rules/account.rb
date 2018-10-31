# == Schema Information
#
# Table name: spree_promotion_rules
#
#  id               :integer          not null, primary key
#  promotion_id     :integer
#  user_id          :integer
#  product_group_id :integer
#  type             :string
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  code             :string
#  preferences      :text
#

module Spree
  class Promotion
    module Rules
      class Account < Spree::PromotionRule
        belongs_to :user, class_name: "::#{Spree.user_class.to_s}"

        has_and_belongs_to_many :accounts, class_name: "Spree::Account",
              join_table: 'spree_promotion_rules_accounts',
              foreign_key: 'promotion_rule_id',
              association_foreign_key: :account_id

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          accounts.include?(order.account)
        end

        # def actionable?(line_item)
        #
        # end

        def account_ids_string
          account_ids.join(',')
        end

        def account_ids_string=(s)
          self.account_ids = s.to_s.split(',').map(&:strip)
        end
      end
    end
  end
end
