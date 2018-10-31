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
      class Variant < Spree::PromotionRule
        has_and_belongs_to_many :variants, class_name: 'Spree::Variant',
          join_table: 'spree_promotion_rules_variants', foreign_key: 'promotion_rule_id'

        MATCH_POLICIES = %w(any all none)
        preference :match_policy, :string, default: MATCH_POLICIES.first

        def eligible_variants
          variants
        end

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          return true if eligible_variants.empty?

          if preferred_match_policy == 'all'
            unless eligible_variants.all? {|v| order.variants.include?(v) }
              eligibility_errors.add(:base, eligibility_error_message(:missing_variant))
            end
          elsif preferred_match_policy == 'any'
            unless order.variants.any? {|v| eligible_variants.include?(v) }
              eligibility_errors.add(:base, eligibility_error_message(:no_applicable_variants))
            end
          else
            unless order.variants.none? {|v| eligible_variants.include?(v) }
              eligibility_errors.add(:base, eligibility_error_message(:has_excluded_variant))
            end
          end

          eligibility_errors.empty?
        end

        def actionable?(line_item)
          case preferred_match_policy
          when 'any', 'all'
            variant_ids.include? line_item.variant_id
          when 'none'
            variant_ids.exclude? line_item.variant_id
          else
            raise "unexpected match policy: #{preferred_match_policy.inspect}"
          end
        end

        def variant_ids_string
          variant_ids.join(',')
        end

        def variant_ids_string=(s)
          self.variant_ids = s.to_s.split(',').map(&:strip)
        end
      end
    end
  end
end
