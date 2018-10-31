class AddEvenMoreIndexes < ActiveRecord::Migration
  def change
    add_index :spree_accounts, :payment_terms_id

    add_index :spree_bookkeeping_documents, :printable_id
    add_index :spree_bookkeeping_documents, :printable_type
    add_index :spree_bookkeeping_documents, [:printable_id, :printable_type], name: "index_spree_bookkeeping_documents_on_printable"

    add_index :spree_countries, :iso_name
    add_index :spree_countries, :iso
    add_index :spree_countries, :iso3
    add_index :spree_countries, :name

    add_index :spree_credit_cards, :gateway_customer_profile_id
    add_index :spree_credit_cards, :gateway_payment_profile_id

    add_index :spree_customer_returns, :stock_location_id

    add_index :spree_customers, :name
    add_index :spree_customers, :spree_account_id
    add_index :spree_customers, :bill_address_id

    add_index :spree_option_types_prototypes, :prototype_id
    add_index :spree_option_types_prototypes, :option_type_id
    add_index :spree_option_types_prototypes, [:prototype_id, :option_type_id], name: "index_spree_option_types_prototypes_on_prototype_option_type"

    remove_column :spree_orders, :quickbooks_created_at
    remove_column :spree_orders, :quickbooks_updated_at

    add_index :spree_orders_promotions, :order_id
    add_index :spree_orders_promotions, :promotion_id

    add_index :spree_payment_terms, :name

    add_index :spree_products_promotion_rules, [:product_id, :promotion_rule_id], name: "index_spree_products_promotion_rules_on_product_promotion_rule"

    add_index :spree_promotion_categories, :name

    add_index :spree_promotion_rules, :type
    add_index :spree_promotion_rules, :code

    add_index :spree_promotion_rules_accounts, [:account_id, :promotion_rule_id], name: "index_spree_promotion_rules_accounts_on_account_promotion_rule"

    add_index :spree_promotion_rules_users, [:user_id, :promotion_rule_id], name: "index_spree_promotion_rules_users_on_user_promotion_rule"
    add_index :spree_promotion_rules_variants, [:variant_id, :promotion_rule_id], name: "index_spree_promotion_rules_variants_on_variant_promotion_rule"

    add_index :spree_promotions, :name

    add_index :spree_properties, :name
    add_index :spree_properties, :presentation

    add_index :spree_properties_prototypes, :prototype_id
    add_index :spree_properties_prototypes, :property_id
    add_index :spree_properties_prototypes, [:prototype_id, :property_id], name: "index_spree_properties_prototypes_on_prototype_and_property"

    add_index :spree_prototypes, :name

    add_index :spree_refund_reasons, :name
    add_index :spree_refund_reasons, :active

    add_index :spree_refunds, :payment_id
    add_index :spree_refunds, :transaction_id
    add_index :spree_refunds, :reimbursement_id

    add_index :spree_return_authorization_reasons, :name
    add_index :spree_return_authorization_reasons, :active

    add_index :spree_return_authorizations, :number
    add_index :spree_return_authorizations, :state
    add_index :spree_return_authorizations, :order_id
    add_index :spree_return_authorizations, :stock_location_id

    add_index :spree_return_items, :return_authorization_id
    add_index :spree_return_items, :inventory_unit_id
    add_index :spree_return_items, :exchange_variant_id
    add_index :spree_return_items, :reimbursement_id
    add_index :spree_return_items, :preferred_reimbursement_type_id
    add_index :spree_return_items, :override_reimbursement_type_id

    add_index :spree_roles, :name

    add_index :spree_roles_users, [:role_id, :user_id]

    add_index :spree_shipping_categories, :name

    add_index :spree_shipping_method_categories, :shipping_category_id

    add_index :spree_shipping_methods, :name

    add_index :spree_shipping_rates, :shipping_method_id

    add_index :spree_standing_line_items, [:variant_id, :standing_order_id], name: "index_spree_standing_line_items_on_variant_and_standing_order"

    add_index :spree_standing_order_trackers, :standing_order_id
    add_index :spree_standing_order_trackers, :active
    add_index :spree_standing_order_trackers, [:standing_order_id, :active], name: "index_spree_standing_order_trackers_on_standing_order_active"
    add_index :spree_standing_order_trackers, :tracking_since

    add_index :spree_standing_orders, :shipping_method_id

    add_index :spree_states, :name
    add_index :spree_states, :abbr

    add_index :spree_stock_movements, :originator_id
    add_index :spree_stock_movements, :originator_type
    add_index :spree_stock_movements, [:originator_id, :originator_type], name: "index_spree_stock_movements_on_originator"

    add_index :spree_tax_categories, :name

    add_index :spree_taxonomies, :name
    add_index :spree_taxons, :name

    add_index :spree_taxons_promotion_rules, [:taxon_id, :promotion_rule_id], name: "index_spree_taxons_promotion_rules_on_taxon_promotion_rule"
    add_index :spree_taxons_prototypes, [:taxon_id, :prototype_id]

    add_index :spree_trackers, :analytics_id

    add_index :spree_vendors, :name
    add_index :spree_vendors, :slug
    add_index :spree_vendors, :email
  end
end
