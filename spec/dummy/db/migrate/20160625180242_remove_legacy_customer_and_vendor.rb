class RemoveLegacyCustomerAndVendor < ActiveRecord::Migration
  def change
    remove_column :spree_accounts,              :vendor_lid, :integer
    remove_column :spree_accounts,              :customer_lid, :integer

    remove_column :spree_customer_imports,      :vendor_lid, :integer

    remove_column :spree_customer_types,        :vendor_lid, :integer

    remove_column :spree_integration_items,     :vendor_lid, :integer

    remove_column :spree_invoices,              :vendor_lid, :integer

    remove_column :spree_option_values,         :vendor_lid, :integer

    remove_column :spree_orders,                :vendor_lid, :integer
    remove_column :spree_orders,                :customer_lid, :integer

    remove_column :spree_products,              :vendor_lid, :integer

    remove_column :spree_product_imports,       :vendor_lid, :integer

    remove_column :spree_promotion_categories,  :vendor_lid, :integer

    remove_column :spree_promotions,            :vendor_lid, :integer

    remove_column :spree_reps,                  :vendor_lid, :integer

    remove_column :spree_shipping_categories,   :vendor_lid, :integer

    remove_column :spree_standing_orders,       :vendor_lid, :integer
    remove_column :spree_standing_orders,       :customer_lid, :integer

    remove_column :spree_stock_locations,       :vendor_lid, :integer

    remove_column :spree_taxons,                :vendor_lid, :integer

    remove_column :spree_taxonomies,            :vendor_lid, :integer

    remove_column :spree_users,                 :vendor_lid, :integer
    remove_column :spree_users,                 :customer_lid, :integer

    drop_table :spree_customers
    drop_table :spree_vendors

  end
end
