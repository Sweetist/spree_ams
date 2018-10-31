class CreateSpreePriceListVariants < ActiveRecord::Migration
  def change
    create_table :spree_price_list_variants do |t|
      t.integer :variant_id
    	t.integer :price_list_id
    	t.decimal :price, precision: 10, scale: 2, default: 0, null: false
    	t.timestamps
    end

    add_index :spree_price_list_variants, :variant_id
    add_index :spree_price_list_variants, :price_list_id
    add_index :spree_price_list_variants, :price
  end
end
