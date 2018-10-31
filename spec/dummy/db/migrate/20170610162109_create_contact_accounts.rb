class CreateContactAccounts < ActiveRecord::Migration
  def change
    create_table :spree_contact_accounts do |t|
    	t.integer :account_id, null: false
			t.integer :contact_id, null: false
      t.timestamps null: false
    end

    add_index :spree_contact_accounts, :account_id
		add_index :spree_contact_accounts, :contact_id
  end
end
