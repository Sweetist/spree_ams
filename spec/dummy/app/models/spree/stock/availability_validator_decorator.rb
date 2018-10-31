Spree::Stock::AvailabilityValidator.class_eval do
  def validate(line_item)
    line_item.quantity_by_variant.each do |variant, variant_quantity|
      inventory_units = line_item.unit_sum(variant)
      quantity = variant_quantity - inventory_units

      next if quantity <= 0

      quantifier = Spree::Stock::Quantifier.new(variant)
      unless quantifier.can_supply? quantity
        line_item.errors[:quantity] << Spree.t(
          :selected_quantity_not_available,
          item: variant.flat_or_nested_name,
          available_qty: [variant.total_on_hand, 0].max
        )
      end
    end
  end
end
