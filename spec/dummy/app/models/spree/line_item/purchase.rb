module Spree::LineItem::Purchase
  extend ActiveSupport::Concern
  included do
    after_update :update_inventory_on_received_item,
                 if: :should_update_received_item?
  end

  def current_cost_price
    variant.current_cost_price
  end

  def should_update_received_item?
    return true if quantity_changed?                           \
                   && order.purchase_order?                    \
                   && variant.should_track_inventory?          \
                   && States[order.state] >= States['shipped']
    false
  end

  def update_inventory_on_received_item
    qty = quantity - quantity_was
    if qty < 0
      order.po_stock_location.unstock(variant, qty * -1, order)
    else
      order.po_stock_location.restock(variant, qty, order)
    end
  end

  def update_variant_cost
    return if quantity.zero?
    old_cost_price = variant.current_cost_price
    variant.update_columns(
      avg_cost_price: variant.weighted_avg_cost(quantity, price),
      last_cost_price: price
    )
    variant.reload

    vendor_variant = variant.variant_vendors.find_or_initialize_by(
      account_id: order.account_id
    )

    vendor_variant.cost_price = price
    vendor_variant.save
    # this lets us know if we need to update assemblies/bundles afterwards
    variant.current_cost_price == old_cost_price ? nil : variant_id
  end

  def add_vendor_to_variant
    vendor_variant = variant.variant_vendors.find_or_create_by(
      account_id: order.account_id
    )
  end
end
