class ChangePaymentTermsToNullable < ActiveRecord::Migration
  def change
    change_column :spree_accounts, :payment_terms, :string, :null => true
  end
end
