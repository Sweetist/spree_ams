class CreateSpreeAccounts < ActiveRecord::Migration
  def change
    create_table  :spree_accounts do |t|
      t.integer   :payment_terms, null: false
      t.decimal   :balance, null: false, default: 0.0
      t.string    :status
      t.decimal   :discount, null: false, default: 0.0
      t.decimal   :cost_price_discount, null: false, default: 0.0
      t.string    :discount_type, null: false, default: 'None'
      t.integer   :customer_id
      t.integer   :vendor_id

      t.timestamps null: false
    end

    add_index(:spree_accounts, :vendor_id)
    add_index(:spree_accounts, :customer_id)
  end
end
