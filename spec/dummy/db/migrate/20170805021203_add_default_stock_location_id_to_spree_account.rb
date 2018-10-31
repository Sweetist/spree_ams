class AddDefaultStockLocationIdToSpreeAccount < ActiveRecord::Migration
  def up
    add_column :spree_accounts, :default_stock_location_id, :integer, index: true

    Spree::Account.all.each do |account|
      next unless account.vendor || account.vendor.stock_locations
      stock_location = account.vendor.stock_locations.find_by(default: true)
      first_stock = account.vendor.stock_locations.first
      account.update_column(:default_stock_location_id, stock_location.try(:id) || first_stock.try(:id))
    end
  end

  def down
    remove_column :spree_accounts, :default_stock_location_id
  end
end
