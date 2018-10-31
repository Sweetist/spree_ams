class CreateSpreeCreditMemos < ActiveRecord::Migration
  def change
    create_table :spree_credit_memos do |t|
      t.references :vendor, index: true
      t.references :account, index: true
      t.string :number
      t.decimal :total, precision: 15, scale: 5, default: 0
      t.decimal :item_total, precision: 15, scale: 5, default: 0
      t.decimal :additional_tax_total, precision: 15, scale: 5, default: 0
      t.decimal :included_tax_total, precision: 15, scale: 5, default: 0
      t.decimal :shipment_total, precision: 15, scale: 5, default: 0
      t.decimal :amount_remaining, precision: 15, scale: 5, default: 0

      t.timestamps null: false
    end
  end
end
