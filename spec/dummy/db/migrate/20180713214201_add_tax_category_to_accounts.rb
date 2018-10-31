class AddTaxCategoryToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :tax_category_id, :integer
    add_index :spree_accounts, :tax_category_id
  end
end
