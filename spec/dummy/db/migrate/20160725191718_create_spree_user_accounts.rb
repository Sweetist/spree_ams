class CreateSpreeUserAccounts < ActiveRecord::Migration
  def change
    create_table :spree_user_accounts do |t|
    	t.integer :account_id, null: false
			t.integer :user_id, null: false
			t.timestamps
    end

    add_index :spree_user_accounts, :account_id
		add_index :spree_user_accounts, :user_id
  end
end
