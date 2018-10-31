module Integrations
  module Inventory
    def process!
      return unless variant_object.should_track_inventory?
      return if quantity == current_qty
      transfer = vendor_object.stock_transfers.create!(
        destination_location: stock_location_object,
        transfer_type: 'adjustment',
        reference: 'Integration Action'
      )
      transfer.receive(stock_location_object, variant_object => qty_for_update)
    end

    private

    def qty_for_update
      quantity - current_qty
    end

    def current_qty
      stock_item_object.count_on_hand || 0
    end

    def stock_item_object
      stock_item = variant_object.stock_items
                                 .find_by(stock_location: stock_location_object)
      return stock_item if stock_item
      raise Error, I18n.t('integrations.stock_item_not_found',
                          variant: variant_object.fully_qualified_name,
                          stock_location: stock_location.name)
    end

    def variant_object
      variant = vendor_object.variants_including_master.find_by(sku: product_id)
      return variant if variant

      raise Error, I18n.t('integrations.variant_for_vendor_not_found',
                          sku: product_id, vendor: vendor_object.name)
    end
  end
end
