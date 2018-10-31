class ChangeDefaultsOnInvoiceDecimals < ActiveRecord::Migration
  def change
    change_column :spree_invoices, :item_total, :decimal, default: 0.0, null: false
    change_column :spree_invoices, :total, :decimal, default: 0.0, null: false
    change_column :spree_invoices, :adjustment_total, :decimal, default: 0.0, null: false
    change_column :spree_invoices, :promo_total, :decimal, default: 0.0, null: false
    change_column :spree_invoices, :shipment_total, :decimal, default: 0.0, null: false
    change_column :spree_invoices, :additional_tax_total, :decimal, default: 0.0, null: false
    change_column :spree_invoices, :included_tax_total, :decimal, default: 0.0, null: false
  end
end
