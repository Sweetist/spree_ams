class AddPurchaseFromAnyToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :purchase_from_any, :boolean, default: true, null: false
    add_index  :spree_variants, :purchase_from_any
  end
end
