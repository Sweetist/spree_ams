class AddCarriersToSpreeVendor < ActiveRecord::Migration
  def change
    add_column :spree_companies, :carriers, :json
  end
end
