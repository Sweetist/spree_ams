# == Schema Information
#
# Table name: spree_order_rules
#
#  id          :integer          not null, primary key
#  vendor_id   :integer
#  active      :boolean          default(TRUE), not null
#  rule_type   :integer          not null
#  value       :integer
#  created_at  :datetime         not null
#  updated_at  :datetime         not null
#  taxon_ids   :string
#  description :string
#

module Spree
  # Order rule class
  class OrderRule < ActiveRecord::Base
    belongs_to :vendor, class_name: 'Spree::Company',
                        foreign_key: :vendor_id, primary_key: :id

    enum rule_type: { minimum_total_value: 0,
                      minimum_total_qty: 1,
                      increment_total_value: 2,
                      increment_total_qty: 3,
                      variant_minimum_order_qty: 4 }

    validates :rule_type, :vendor_id, presence: true

    scope :active, (-> { where(active: true) })

    serialize :taxon_ids, Array

    before_validation do |model|
      model.taxon_ids.reject!(&:blank?) if model.taxon_ids
    end

    def self.user_rule_types
      Spree::OrderRule.rule_types.except(:variant_minimum_order_qty).keys
    end

    def self.create_moq_rule_if_not_exist(vendor)
      Spree::OrderRule.variant_minimum_order_qty.find_or_create_by(vendor: vendor)
    end

    def label_text
      return 'Quantity' if rule_type == 'minimum_total_qty' || rule_type == 'increment_total_qty'
      'Value'
    end

    def name
      return '' unless rule_type
      taxon_names = Spree::Taxon.where(id: taxon_ids).pluck(:name).join(', ')
      rule_type.include?('value') ? text_value = "#{Spree::CurrencyHelper.currency_symbol(vendor.currency)}#{value}" : text_value = value

      case rule_type
      when 'variant_minimum_order_qty'
        return Spree.t(rule_type) if taxon_ids.empty?
        "#{Spree.t(rule_type)} on #{taxon_names} category"
      else
        return "#{Spree.t(rule_type)}: #{text_value} on entire order" if taxon_ids.empty?
        "#{Spree.t(rule_type)}: #{text_value} on #{taxon_names} category"
      end
    end

    def message(order)
      return "Order does not satisfy the rule: '#{name}'" if rule_type != 'variant_minimum_order_qty'

      variants_names = not_eligible_moq_variants(order)
                       .map { |v| [v.variant.flat_or_nested_name,
                                   v.variant.minimum_order_quantity]}.join(', ')
      "Order does not satisfy the rule: '#{name}' in '#{variants_names}'"
    end

    def valid_for?(order)
      return true unless taxons_ids_related_with_order?(order)
      send("#{rule_type}_rule", order)
    end

    def taxons_ids_related_with_order?(order)
      return true if taxon_ids.empty? # Hack for nil taxons
      (taxons_including_children_ids & order.taxons.map(&:id)).present?
    end

    private

    def quantity_related_with_taxons(order)
      return order.quantity if taxon_ids.empty?
      if order.class.name == 'Spree::Order'
        order_quantity_related_with_taxons(order)
      elsif order.class.name == 'Spree::StandingOrder'
        standing_quantity_related_with_taxons(order)
      end
    end

    def order_quantity_related_with_taxons(order)
      (products_line_items(order) + variants_line_items(order)).sum(&:quantity)
    end

    def standing_quantity_related_with_taxons(order)
      (standing_products_line_items(order) +
        standing_variants_line_items(order)).sum(&:quantity)
    end

    def item_total_related_with_taxons(order)
      return order.item_total if taxon_ids.empty?

      if order.class.name == 'Spree::Order'
        order_total_related_with_taxons(order)
      elsif order.class.name == 'Spree::StandingOrder'
        standing_total_related_with_taxons(order)
      end
    end

    def order_total_related_with_taxons(order)
      (products_line_items(order) + variants_line_items(order)).map(&:total).sum
    end

    def standing_total_related_with_taxons(order)
      (standing_products_line_items(order) +
        standing_variants_line_items(order)).map(&:total).sum
    end

    def taxons_including_children_ids
      taxons = Spree::Taxon.where(id: taxon_ids)
      taxons.inject([]) { |ids, taxon| ids + taxon.self_and_descendants.ids }
    end

    def products_line_items(order)
      Spree::LineItem.joins(:order, variant: { product: :taxons })
                     .where("spree_orders.id = #{order.id} and spree_taxons.id IN (?)",
                            taxons_including_children_ids)
    end

    def variants_line_items(order)
      Spree::LineItem.joins(:order, variant: :taxons)
                     .where("spree_orders.id = #{order.id} and spree_taxons.id IN (?)",
                            taxons_including_children_ids)
    end

    def standing_products_line_items(order)
      Spree::StandingLineItem.joins(:standing_order, variant: { product: :taxons })
                             .where("spree_standing_orders.id = #{order.id} and spree_taxons.id IN (?)",
                                    taxons_including_children_ids)
    end

    def standing_variants_line_items(order)
      Spree::StandingLineItem.joins(:standing_order, variant: :taxons)
                             .where("spree_standing_orders.id = #{order.id} and spree_taxons.id IN (?)",
                                    taxons_including_children_ids)
    end

    def not_eligible_moq_variants(order)
      result = []
      order.line_items.each do |line_item|
        if line_item.variant.minimum_order_quantity > line_item.quantity
          result << line_item
        end
      end
      result
    end

    def variant_minimum_order_qty_rule(order)
      return true if not_eligible_moq_variants(order).empty?
      false
    end

    def increment_total_qty_rule(order)
      return true if (quantity_related_with_taxons(order) % value).zero?
      false
    end

    def increment_total_value_rule(order)
      return true if (item_total_related_with_taxons(order) % value).zero?
      false
    end

    def minimum_total_qty_rule(order)
      return true if quantity_related_with_taxons(order) >= value
      false
    end

    def minimum_total_value_rule(order)
      return true if item_total_related_with_taxons(order) >= value
      false
    end
  end
end
