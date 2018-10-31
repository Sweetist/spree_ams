class ChangeOrderCutOffTimeDataType < ActiveRecord::Migration
  def change
    change_column :spree_vendors, :order_cutoff_time, :string, null: false
  end
end
