class ChangeColumnNameCreditUsedOnSpreeAccountPayment < ActiveRecord::Migration
  def change
    rename_column :spree_account_payments, :credit_used, :credit_to_apply
  end
end
