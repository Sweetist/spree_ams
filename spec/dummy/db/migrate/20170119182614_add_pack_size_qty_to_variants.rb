class AddPackSizeQtyToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :pack_size_qty, :integer
  end
end
