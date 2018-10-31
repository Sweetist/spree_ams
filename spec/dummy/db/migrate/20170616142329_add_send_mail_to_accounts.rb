class AddSendMailToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :send_mail, :string
  end
end
