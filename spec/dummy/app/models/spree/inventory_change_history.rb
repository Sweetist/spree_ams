module Spree
  class InventoryChangeHistory < SecondBase::Base
    self.table_name = 'inventory_change_histories'

    validates :quantity, presence: true
    validates :quantity_on_hand, presence: true
    validates :stock_item_id, presence: true
    validates :stock_location_id, presence: true
    validates :variant_id, presence: true
    validates :action, presence: true
    validates :originator_id, presence: true
    validates :originator_type, presence: true
    validates :originator_number, presence: true
    validates :item_variant_name, presence: true
    validates :item_variant_sku, presence: true
    validates :stock_movement_id, presence: true
  end
end
