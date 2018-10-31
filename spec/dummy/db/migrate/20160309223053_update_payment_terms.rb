class UpdatePaymentTerms < ActiveRecord::Migration
  def change
    remove_column :spree_vendors, :payment_terms
    remove_column :spree_accounts, :payment_terms
    add_column :spree_accounts, :payment_terms_id, :integer
  end
end
