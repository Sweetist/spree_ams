class CreateAccountPaymentMethods < ActiveRecord::Migration
  def change
    create_table :spree_account_payment_methods do |t|
      t.integer :payment_method_id
      t.integer :account_id
      t.timestamps null: false
    end
  end
end
