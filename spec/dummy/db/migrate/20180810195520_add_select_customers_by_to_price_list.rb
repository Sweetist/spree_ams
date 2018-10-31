class AddSelectCustomersByToPriceList < ActiveRecord::Migration
  def change
    add_column :spree_price_lists, :select_customers_by, :string, default: 'individual', null: false
    add_index  :spree_price_lists, :select_customers_by
  end
end
