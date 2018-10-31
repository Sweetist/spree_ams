class AddLastDeliveryDateToAccounts < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :last_ordered_at, :datetime
    add_column :spree_accounts, :last_delivery_date, :datetime
    add_index  :spree_accounts, :last_ordered_at
    add_index  :spree_accounts, :last_delivery_date
  end
end
