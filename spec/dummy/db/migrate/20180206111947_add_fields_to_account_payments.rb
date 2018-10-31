class AddFieldsToAccountPayments < ActiveRecord::Migration
  def change
    add_column :spree_account_payments, :source_id, :integer, index: true
    add_column :spree_account_payments, :source_type, :string
    add_column :spree_account_payments, :payment_method_id, :integer, index: true
    add_column :spree_account_payments, :state, :string
    add_column :spree_account_payments, :response_code, :string
    add_column :spree_account_payments, :avs_response, :string
    add_column :spree_account_payments, :currency, :string
    add_column :spree_account_payments, :number, :string
  end
end
