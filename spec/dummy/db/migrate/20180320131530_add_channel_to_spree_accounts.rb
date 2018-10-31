class AddChannelToSpreeAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :channel, :string, default: 'sweet', null: false
    add_index  :spree_accounts, :channel
  end
end
