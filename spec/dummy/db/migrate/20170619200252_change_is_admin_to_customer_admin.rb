class ChangeIsAdminToCustomerAdmin < ActiveRecord::Migration
  def change
      rename_column :spree_users, :is_admin, :customer_admin
  end
end
