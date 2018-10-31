class AddColumnsToCreditCard < ActiveRecord::Migration
  def change
    add_column :spree_credit_cards, :account_id, :integer

    add_index :spree_credit_cards, :account_id
  end
end
