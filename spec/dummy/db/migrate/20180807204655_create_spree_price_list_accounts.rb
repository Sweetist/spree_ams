class CreateSpreePriceListAccounts < ActiveRecord::Migration
  def change
    create_table :spree_price_list_accounts do |t|
      t.integer :price_list_id
    	t.integer :account_id
    end

    add_index :spree_price_list_accounts, :account_id
    add_index :spree_price_list_accounts, :price_list_id

  end
end
