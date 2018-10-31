class AddTaxExemptNumberToCustomer < ActiveRecord::Migration
  def change
    add_column :spree_customers, :tax_exempt_id, :string
    add_index :spree_customers, :tax_exempt_id
  end
end
