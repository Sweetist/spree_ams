class ChangeVendorCustomerIds < ActiveRecord::Migration
  def change
    rename_column :spree_accounts,              :vendor_id,     :vendor_lid
    rename_column :spree_accounts,              :customer_id,   :customer_lid

    rename_column :spree_customer_imports,      :vendor_id,     :vendor_lid

    rename_column :spree_customer_types,        :vendor_id,     :vendor_lid

    rename_column :spree_integration_items,     :vendor_id,     :vendor_lid

    rename_column :spree_invoices,              :vendor_id,     :vendor_lid

    rename_column :spree_option_values,         :vendor_id,     :vendor_lid

    rename_column :spree_orders,                :vendor_id,     :vendor_lid
    rename_column :spree_orders,                :customer_id,   :customer_lid

    rename_column :spree_products,              :vendor_id,     :vendor_lid

    rename_column :spree_product_imports,       :vendor_id,     :vendor_lid

    rename_column :spree_promotion_categories,  :vendor_id,     :vendor_lid

    rename_column :spree_promotions,            :vendor_id,     :vendor_lid

    rename_column :spree_reps,                  :vendor_id,     :vendor_lid

    rename_column :spree_shipping_categories,   :vendor_id,     :vendor_lid

    rename_column :spree_standing_orders,       :vendor_id,     :vendor_lid
    rename_column :spree_standing_orders,       :customer_id,   :customer_lid

    rename_column :spree_stock_locations,       :vendor_id,     :vendor_lid

    rename_column :spree_taxons,                :vendor_id,     :vendor_lid

    rename_column :spree_taxonomies,            :vendor_id,     :vendor_lid

    rename_column :spree_users,                 :vendor_id,     :vendor_lid
    rename_column :spree_users,                 :customer_id,   :customer_lid

  end
end
