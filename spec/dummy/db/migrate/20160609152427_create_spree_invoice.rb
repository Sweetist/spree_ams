class CreateSpreeInvoice < ActiveRecord::Migration
  def change
    create_table :spree_invoices do |t|
      t.datetime  :start_date
      t.datetime  :end_date
      t.boolean   :multi_order
      t.string    :number
      t.string    :state
      t.decimal   :item_total
      t.decimal   :total
      t.decimal   :adjustment_total
      t.integer   :bill_address_id
      t.integer   :ship_address_id
      t.decimal   :payment_total
      t.string    :payment_state
      t.datetime  :payment_due_date
      t.string    :currency
      t.decimal   :shipment_total
      t.decimal   :additional_tax_total
      t.decimal   :promo_total
      t.decimal   :included_tax_total
      t.integer   :item_count
      t.integer   :account_id
      t.integer   :vendor_id
      t.boolean   :confirm_sent
      t.boolean   :confirm_returned

      t.timestamps
    end

    add_index :spree_invoices, :number
    add_index :spree_invoices, :total
    add_index :spree_invoices, :state
    add_index :spree_invoices, :payment_state
    add_index :spree_invoices, :account_id
    add_index :spree_invoices, :vendor_id
    add_index :spree_invoices, :multi_order
  end
end
