class CreateSpreeCreditTransactions < ActiveRecord::Migration
  def change
    create_table :spree_credit_transactions do |t|
      t.boolean :use_credit, default: false
      t.integer :account_id, index: true, null: false
      t.decimal :amount, precision: 15, scale: 5, default: 0, null: false
      t.references :creditable, polymorphic: true,
                                index: { name: 'index_creditable_poly' },
                                null: false

      t.timestamps null: false
    end
  end
end
