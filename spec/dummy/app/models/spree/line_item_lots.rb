module Spree
  class LineItemLots < Spree::Base
    belongs_to :lot
    belongs_to :line_item
    belongs_to :part_variant, class_name: "Spree::Variant", foreign_key: :variant_part_id, primary_key: :id
    has_many :stock_item_lots, through: :lot, source: :stock_item_lots

    validates :lot, :line_item, presence: true

    # return variant for line_item_lots from line_item
    # and return variant from line_item part if root variant type is bundle
    #
    # uses for saving info when line item is bundle with lots
    # look at line_item_lot_for(variant) in line_item_decorator
    def variant
      return line_item.variant unless line_item.variant.is_bundle?

      line_item.variant.parts.find_by(id: variant_part_id)
    end

    def display_lot(opts = {})
      if opts[:sparse]
        "#{opts[:prefix]}#{self.lot.try(:number)} (#{self.count})"
      else
        "#{opts[:prefix]}#{self.part_or_variant} - #{self.lot.try(:number)} (#{self.count})"
      end
    end

    def part_or_variant
      "#{(self.part_variant || self.line_item.try(:variant)).try(:flat_or_nested_name)}"
    end
  end
end
