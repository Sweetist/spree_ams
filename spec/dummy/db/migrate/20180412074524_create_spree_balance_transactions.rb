class CreateSpreeBalanceTransactions < ActiveRecord::Migration
  def change
    create_table :spree_balance_transactions do |t|
      t.integer :account_id, index: true, null: false
      t.decimal :amount, precision: 15, scale: 5, default: 0, null: false
      t.references :originator, polymorphic: true,
                                index: { name: 'index_balance_orig_pol' },
                                null: false

      t.timestamps null: false
    end
  end
end
