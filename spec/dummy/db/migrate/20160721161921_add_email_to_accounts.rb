class AddEmailToAccounts < ActiveRecord::Migration
  def change
		add_column :spree_accounts, :email, :string
  end
end
