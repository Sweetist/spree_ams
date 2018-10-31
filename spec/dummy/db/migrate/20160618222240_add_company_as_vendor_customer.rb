class AddCompanyAsVendorCustomer < ActiveRecord::Migration
  def up
    add_column :spree_accounts,              :vendor_id,     :integer
    add_column :spree_accounts,              :customer_id,   :integer
    Spree::Account.find_each do |account|
      account.update_columns(
        vendor_id: account.try(:legacy_vendor).try(:company_id),
        customer_id: account.try(:legacy_customer).try(:company_id)
      )
    end
    add_column :spree_customer_imports,      :vendor_id,     :integer
    Spree::CustomerImport.find_each do |customer_import|
      customer_import.update_columns(vendor_id: customer_import.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_customer_types,        :vendor_id,     :integer
    Spree::CustomerType.find_each do |customer_type|
      customer_type.update_columns(vendor_id: customer_type.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_integration_items,     :vendor_id,     :integer
    Spree::IntegrationItem.find_each do |integration_item|
      integration_item.update_columns(vendor_id: integration_item.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_invoices,              :vendor_id,     :integer
    Spree::Invoice.find_each do |invoice|
      invoice.update_columns(vendor_id: invoice.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_option_values,         :vendor_id,     :integer
    Spree::OptionValue.find_each do |option_value|
      option_value.update_columns(vendor_id: option_value.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_orders,                :vendor_id,     :integer
    add_column :spree_orders,                :customer_id,   :integer
    Spree::Order.find_each do |order|
      order.update_columns(
      vendor_id: order.try(:legacy_vendor).try(:company_id),
      customer_id: order.try(:legacy_customer).try(:company_id))
    end

    add_column :spree_products,              :vendor_id,     :integer
    Spree::Product.find_each do |product|
      product.update_columns(vendor_id: product.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_product_imports,       :vendor_id,     :integer
    Spree::ProductImport.find_each do |product_import|
      product_import.update_columns(vendor_id: product_import.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_promotion_categories,  :vendor_id,     :integer
    Spree::PromotionCategory.find_each do |promotion_category|
      promotion_category.update_columns(vendor_id: promotion_category.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_promotions,            :vendor_id,     :integer
    Spree::Promotion.find_each do |promotion|
      promotion.update_columns(vendor_id: promotion.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_reps,                  :vendor_id,     :integer
    Spree::Rep.find_each do |rep|
      rep.update_columns(vendor_id: rep.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_shipping_categories,   :vendor_id,     :integer
    Spree::ShippingCategory.find_each do |shipping_category|
      shipping_category.update_columns(vendor_id: shipping_category.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_standing_orders,       :vendor_id,     :integer
    add_column :spree_standing_orders,       :customer_id,   :integer
    Spree::StandingOrder.find_each do |standing_order|
      standing_order.update_columns(
        vendor_id: standing_order.try(:legacy_vendor).try(:company_id),
        customer_id: standing_order.try(:legacy_customer).try(:company_id)
      )
    end

    add_column :spree_stock_locations,       :vendor_id,     :integer
    Spree::StockLocation.find_each do |stock_location|
      stock_location.update_columns(vendor_id: stock_location.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_taxons,                :vendor_id,     :integer
    Spree::Taxon.find_each do |taxon|
      taxon.update_columns(vendor_id: taxon.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_taxonomies,            :vendor_id,     :integer
    Spree::Taxonomy.find_each do |taxonomy|
      taxonomy.update_columns(vendor_id: taxonomy.try(:legacy_vendor).try(:company_id))
    end

    add_column :spree_users,                 :company_id,     :integer
    Spree::User.find_each do |user|
      user.update_columns(
        company_id: user.try(:legacy_vendor).try(:company_id) ||
        user.try(:legacy_customer).try(:company_id)
      )
    end
  end

  def down
    remove_column :spree_accounts,              :vendor_id,     :integer
    remove_column :spree_accounts,              :customer_id,   :integer
    remove_column :spree_customer_imports,      :vendor_id,     :integer
    remove_column :spree_customer_types,        :vendor_id,     :integer
    remove_column :spree_integration_items,     :vendor_id,     :integer
    remove_column :spree_invoices,              :vendor_id,     :integer
    remove_column :spree_option_values,         :vendor_id,     :integer
    remove_column :spree_orders,                :vendor_id,     :integer
    remove_column :spree_orders,                :customer_id,   :integer
    remove_column :spree_products,              :vendor_id,     :integer
    remove_column :spree_product_imports,       :vendor_id,     :integer
    remove_column :spree_promotion_categories,  :vendor_id,     :integer
    remove_column :spree_promotions,            :vendor_id,     :integer
    remove_column :spree_reps,                  :vendor_id,     :integer
    remove_column :spree_shipping_categories,   :vendor_id,     :integer
    remove_column :spree_standing_orders,       :vendor_id,     :integer
    remove_column :spree_standing_orders,       :customer_id,   :integer
    remove_column :spree_stock_locations,       :vendor_id,     :integer
    remove_column :spree_taxons,                :vendor_id,     :integer
    remove_column :spree_taxonomies,            :vendor_id,     :integer
    remove_column :spree_users,                 :company_id,     :integer

  end
end
