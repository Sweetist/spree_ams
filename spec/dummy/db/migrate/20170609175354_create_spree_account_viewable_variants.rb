class CreateSpreeAccountViewableVariants < ActiveRecord::Migration
  def change
    create_table :spree_account_viewable_variants do |t|
      t.integer :account_id, null: false
      t.integer :variant_id, null: false
      t.boolean :visible
      t.decimal :price, null: false, default: 0
      t.text :promotion_ids, array:true, default: []
      t.integer :recalculating
    end

    add_index :spree_account_viewable_variants, :account_id
    add_index :spree_account_viewable_variants, :variant_id
    add_index :spree_account_viewable_variants, :price
    add_index :spree_account_viewable_variants, :visible
    add_index :spree_account_viewable_variants, :recalculating
  end
end
