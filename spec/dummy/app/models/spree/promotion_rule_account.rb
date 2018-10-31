module Spree
  class PromotionRuleAccount < Spree::Base
    belongs_to :promotion_rule, class_name: 'Spree::PromotionRule'
    belongs_to :account, class_name: 'Spree::Account'
  end
end
