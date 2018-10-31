module Spree::Company::Resets
  extend ActiveSupport::Concern
  RESET_TRANSACTIONS = %i[sales_orders purchase_orders standing_orders payments].freeze
  RESET_RELATIONSHIPS = %i[contacts customers vendors].freeze
  RESET_PRODUCTS = %i[lots products].freeze
  RESET_EVENT_ORDER =
    [
      # :integrations,
      :sales_orders,
      :purchase_orders,
      :standing_orders,
      :payments,
      :contacts,
      :customers,
      :vendors,
      :lots,
      :products
      # :taxons,
      # :customer_imports,
      # :vendor_imports,
      # :product_imports,
      # :promotions,
      # :promotion_categories,
      # :price_lists,
      # :credit_memos,
      # :option_types,
      # :order_rules,
      # :customer_types,
      # :sales_reps,
      # :chart_of_accounts,
      # :stock_locations,
      # :shipping_methods,
      # :shipping_categories,
      # :tax_rates,
      # :tax_categories,
      # :payment_methods,
      # :zones,
      # :custom_forms,
      # :shipping_groups
    ].freeze
  RESET_DEPENDENCIES = {
    products: [:lots, :sales_orders, :purchase_orders],
    customers: [:sales_orders],
    vendors: [:purchase_orders]
  }

  RESET_EVENT_ORDER.each{ |event| attr_reader "destroy_#{event}".to_sym }

  def full_reset
    RESET_EVENT_ORDER.each { |event| self.send("destroy_all_#{event}") }
  end

  def destroy_all_sales_orders
    destroy_all_orders('sales')
  end
  def destroy_all_purchase_orders
    destroy_all_orders('purchase')
  end

  def destroy_all_orders(type = 'sales')
    self.send("#{type}_orders").find_each do |o|
      o.line_items.delete_all
      o.all_adjustments.delete_all
      o.destroy!
    end

    destroy_all_invoices(type)
  end

  def destroy_all_invoices(type = 'sales')
    self.send("#{type}_invoices").destroy_all
  end

  def destroy_all_standing_orders
    self.sales_standing_orders.find_each do |so|
      so.standing_order_schedules.delete_all
      so.standing_line_items.delete_all
      so.destroy!
    end
  end

  def destroy_all_customers
    if sales_orders.present?
      raise Exceptions::DataIntegrity.new('You must delete sales orders before deleting customers.')
    end
    Spree::AccountViewableVariant.where(id: self.account_viewable_variants.ids).delete_all
    self.customer_accounts.destroy_all
  end

  def destroy_all_vendors
    if purchase_orders.present?
      raise Exceptions::DataIntegrity.new('You must delete purchase orders before deleting vendors.')
    end
    self.vendor_accounts.destroy_all
  end

  def destroy_all_products
    if sales_orders.present?
      raise Exceptions::DataIntegrity.new('You must delete sales orders before deleting products.')
    end
    if purchase_orders.present?
      raise Exceptions::DataIntegrity.new('You must delete purchase orders before deleting products.')
    end
    if lots.present?
      raise Exceptions::DataIntegrity.new('You must delete lots before deleting products.')
    end

    Spree::InventoryChangeHistory.where(company_id: self.id).destroy_all
    self.stock_transfers.destroy_all

    Spree::AssembliesPart.where(assembly_id: variants_including_master.ids).destroy_all
    Spree::AssembliesPart.where(part_id: variants_including_master.ids).destroy_all
    products.find_each {|p| p.destroy! }
  end

  def destroy_all_product_imports
    product_imports.delete_all
  end

  def destroy_all_customer_imports
    customer_imports.delete_all
  end

  def destroy_all_vendor_imports
    vendor_imports.delete_all
  end

  def destroy_all_integrations
    integration_items.each do |ii|
      ii.integration_actions.delete_all
      ii.destroy!
    end
  end

  def destroy_all_lots
    Spree::StockItemLots.where(lot_id: lot_ids).delete_all
    Spree::LineItemLots.where(lot_id: lot_ids).delete_all
    # Spree::StockMovement.where(lot_id: lot_ids).update_all(lot_id: nil)
    Spree::InventoryUnit.where(lot_id: lot_ids).update_all(lot_id: nil)
    lots.delete_all
  end

  def destroy_all_promotions
    promotions.destroy_all
  end

  def destroy_all_price_lists
    price_lists.destroy_all
  end

  def destroy_all_contacts
    contacts.destroy_all
  end

  def destroy_all_credit_memos
    credit_memos.destroy_all
  end

  def destroy_all_payments
    sales_payments.destroy_all
    account_payments.destroy_all
  end

  def destroy_all_option_types
    option_types.destroy_all
  end

  def destroy_all_taxons
    taxons.where.not(parent_id: nil).destroy_all
  end

  def destroy_all_promotion_categories
    promotion_categories.destroy_all
  end

  def destroy_all_order_rules

  end
  def destroy_all_customer_types
    customer_accounts.update_all(customer_type_id: nil)
    customer_types.delete_all
  end
  def destroy_all_sales_reps
    customer_accounts.update_all(rep_id: nil)
    reps.delete_all
  end
  def destroy_all_chart_of_accounts
    chart_accounts.delete_all
  end
  def destroy_all_stock_locations

  end
  def destroy_all_shipping_methods
    if sales_orders.present?
      raise Exceptions::DataIntegrity.new('You must delete sales orders before deleting customers.')
    end
    shipping_categories.each do |category|
      category.shipping_methods.delete_all
      category.shipping_method_categories.delete_all
    end
  end
  def destroy_all_shipping_categories
    if shipping_methods.present?
      raise Exceptions::DataIntegrity.new('You must delete shipping methods before deleting shipping categories.')
    end
    shipping_categories.destroy_all
  end
  def destroy_all_tax_rates

  end
  def destroy_all_tax_categories

  end
  def destroy_all_payment_methods

  end
  def destroy_all_zones

  end
  def destroy_all_custom_forms
    Spree::FormField.where(form_id: form_ids).delete_all
    forms.delete_all
  end
  def destroy_all_shipping_groups
    customer_accounts.update_all(shipping_group_id: nil)
    shipping_groups.delete_all
  end

  def reset_inventory!(require_shipped = false, inventory_date = DateHelper.sweet_today(time_zone))
    if require_shipped
      # Check if we have unshipped orders with delivery dates prior to the inventory_date.
      # inventory_date should be the date for which the new inventory numbers to be entered was accurate for.
      unshipped_order_count = self.sales_orders
                      .where('delivery_date < ?', inventory_date)
                      .where(state: ['complete','approved'])
                      .count
      if unshipped_order_count > 0
        raise Exceptions::DataIntegrity.new("You have #{unshipped_order_count } unshipped order(s) with delivery dates prior to today. Please ship them before reseting your inventory.")
      end
    end

    ActiveRecord::Base.transaction do
      stock_items.find_each do |stock_item|
        stock_item.update_columns(on_hand: 0, count_on_hand: (-1 * stock_item.committed))
      end
      lots.update_all(qty_on_hand: 0)
      Spree::StockItemLots.where(lot_id: lots.ids).update_all(count: 0)

      Spree::InventoryUnit.joins(:order, :variant)
                          .where('spree_orders.state IN (?)', %w[complete approved])
                          .where('spree_orders.vendor_id = ?', self.id)
                          .where('spree_variants.variant_type IN (?)', %w[inventory_item inventory_assembly])
                          .where('spree_inventory_units.state = ?', 'on_hand')
                          .update_all(state: 'backordered', lot_id: nil)
      Spree::LineItemLots.joins(line_item: :order)
                         .where('spree_orders.state IN (?)', %w[complete approved])
                         .where('spree_orders.vendor_id = ?', self.id)
                         .delete_all
    end
  end

end
