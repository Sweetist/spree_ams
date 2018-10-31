module Spree
  # Methids for support order rules in Spree::Order and Spree::StandingOrder
  #
  #
  module OrderRequirements
    def errors_from_order_rules
      errors = []
      vendor.order_rules.active.each do |rule|
        errors << rule.message(self) unless rule.valid_for?(self)
      end

      errors
    end

    def taxons
      (variants_taxons + products_taxons).distinct
    end

    private

    def variants_taxons
      Spree::Taxon
        .joins(products: { variants_including_master: :"#{line_item_table}" })
        .where("spree_#{line_item_table}": { "#{order_id_field}": id })
    end

    def products_taxons
      Spree::Taxon
        .joins(variants: :"#{line_item_table}")
        .where("spree_#{line_item_table}": { "#{order_id_field}": id })
    end

    def order_id_field
      if self.class.name == 'Spree::Order'
        'order_id'
      elsif self.class.name == 'Spree::StandingOrder'
        'standing_order_id'
      end
    end

    def line_item_table
      if self.class.name == 'Spree::Order'
        'line_items'
      elsif self.class.name == 'Spree::StandingOrder'
        'standing_line_items'
      end
    end
  end
end
