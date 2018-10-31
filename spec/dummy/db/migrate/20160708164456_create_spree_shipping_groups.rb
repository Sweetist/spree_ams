class CreateSpreeShippingGroups < ActiveRecord::Migration
  def change
    create_table :spree_shipping_groups do |t|
      t.string  :name, null: false
      t.integer :vendor_id
      t.json    :deliverable_days
      t.boolean :is_default, default: false
    end

    add_index   :spree_shipping_groups, :name
    add_index   :spree_shipping_groups, :vendor_id
    add_index   :spree_shipping_groups, :is_default

    add_column  :spree_accounts, :shipping_group_id, :integer
    add_index   :spree_accounts, :shipping_group_id
  end
end
