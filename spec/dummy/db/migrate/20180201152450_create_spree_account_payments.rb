class CreateSpreeAccountPayments < ActiveRecord::Migration
  def change
    create_table :spree_account_payments do |t|
      t.decimal :amount, precision: 15, scale: 5
      t.integer :vendor_id, index: true
      t.integer :account_id, index: true

      t.timestamps null: false
    end
  end
end
