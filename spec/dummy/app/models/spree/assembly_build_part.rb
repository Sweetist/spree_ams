module Spree
  class AssemblyBuildPart < Spree::Base
    belongs_to :assembly_build, class_name: 'Spree::AssemblyBuild',
                                foreign_key: 'build_id'
    belongs_to :variant, class_name: 'Spree::Variant',
                         foreign_key: 'variant_id'
    belongs_to :stock_item_lot, class_name: 'Spree::StockItemLots',
                                foreign_key: 'stock_item_lot_id'
    belongs_to :stock_item, class_name: 'Spree::StockItem',
                            foreign_key: 'stock_item_id'

  end
end
