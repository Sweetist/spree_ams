class CreateSpreeAppliedCredits < ActiveRecord::Migration
  def change
    create_table :spree_applied_credits do |t|
      t.references :credit_memo, index: true
      t.references :account_payment, index: true
      t.decimal :amount, precision: 15, scale: 5, default: 0, null: false

      t.timestamps null: false
    end
  end
end
