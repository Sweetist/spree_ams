class AddMinimumOrderQuantityToSpreeVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :minimum_order_quantity, :integer
  end
end
