module InventoryHistory
  ACTION_TYPES = {
    invoice: 'invoice',
    purchase_order: 'purchase_order',
    adjustment: 'adjustment',
    transfer: 'transfer',
    assembly_build: 'build'
  }.freeze
end
