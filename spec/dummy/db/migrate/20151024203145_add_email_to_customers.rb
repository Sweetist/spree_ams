class AddEmailToCustomers < ActiveRecord::Migration
  def change
		add_column :spree_customers, :email, :string
  end
end
