class ChangeUserIsAdminDefault < ActiveRecord::Migration
  def change
    change_column_default :spree_users, :is_admin, true
  end
end
