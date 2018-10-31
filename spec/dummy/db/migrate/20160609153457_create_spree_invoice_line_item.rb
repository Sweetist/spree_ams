class CreateSpreeInvoiceLineItem < ActiveRecord::Migration
  def change
    create_table :spree_invoice_line_items do |t|
      t.integer :variant_id
      t.integer :invoice_id
      t.integer :ordered_qty
      t.integer :shipped_qty
      t.integer :quantity
      t.decimal :price
      t.string  :currency
      t.decimal :adjustment_total
      t.decimal :additional_tax_total
      t.decimal :promo_total
      t.decimal :included_tax_total
      t.decimal :pre_tax_amount
      t.string  :item_name

      t.timestamps
    end

    add_index :spree_invoice_line_items, :variant_id
    add_index :spree_invoice_line_items, :invoice_id
    add_index :spree_invoice_line_items, :item_name
    add_index :spree_line_items, :item_name
  end
end
