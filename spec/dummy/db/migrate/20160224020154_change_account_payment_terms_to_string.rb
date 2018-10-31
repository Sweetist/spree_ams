class ChangeAccountPaymentTermsToString < ActiveRecord::Migration
  def change
    change_column :spree_accounts, :payment_terms, :string
  end
end
