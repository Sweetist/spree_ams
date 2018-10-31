class ChangeCustomerAdminDefault < ActiveRecord::Migration
  def change
    change_column_default :spree_users, :customer_admin, :false
  end
end
