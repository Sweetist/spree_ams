class AddColumnsToSpreeUsers < ActiveRecord::Migration
  def change
    add_column :spree_users, :firstname, :string
    add_column :spree_users, :lastname, :string
    add_column :spree_users, :phone, :string
    add_column :spree_users, :user_type, :string
    add_column :spree_users, :vendor_id, :integer
    add_column :spree_users, :customer_id, :integer
  end
end
