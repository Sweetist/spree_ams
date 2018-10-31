class AddCvvFieldsToAccountPayments < ActiveRecord::Migration
  def change
    add_column :spree_account_payments, :cvv_response_code, :string
    add_column :spree_account_payments, :cvv_response_message, :string
  end
end
