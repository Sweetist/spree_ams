class AddDiscontinuedOnToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :discontinued_on, :datetime
    add_column :spree_products, :discontinued_on, :datetime

    add_index :spree_variants, :discontinued_on
    add_index :spree_products, :discontinued_on
  end
end
