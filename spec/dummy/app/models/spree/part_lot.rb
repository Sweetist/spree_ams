module Spree
  class PartLot < Spree::Base
    acts_as_nested_set
    belongs_to :assembly_lot, class_name: 'Spree::Lot', foreign_key: :assembly_lot_id, primary_key: :id
    belongs_to :part_lot, class_name: 'Spree::Lot', foreign_key: :part_lot_id, primary_key: :id

    self.whitelisted_ransackable_attributes = %w[assembly_lot_id part_lot_id]
    self.whitelisted_ransackable_associations = %w[part_lot assembly_lot]
  end
end
