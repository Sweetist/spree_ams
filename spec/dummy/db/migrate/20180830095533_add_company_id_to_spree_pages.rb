class AddCompanyIdToSpreePages < ActiveRecord::Migration
  def change
    add_column :spree_pages, :company_id, :integer
    add_index :spree_pages, :company_id
  end
end
