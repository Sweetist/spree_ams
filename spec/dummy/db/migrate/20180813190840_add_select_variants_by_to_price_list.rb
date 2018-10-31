class AddSelectVariantsByToPriceList < ActiveRecord::Migration
  def change
    add_column :spree_price_lists, :select_variants_by, :string, default: 'individual', null: false
  end
end
