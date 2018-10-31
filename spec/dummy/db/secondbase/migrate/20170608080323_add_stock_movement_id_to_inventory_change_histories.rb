class AddStockMovementIdToInventoryChangeHistories < ActiveRecord::Migration
  def change
    add_column :inventory_change_histories, :stock_movement_id, :integer
  end
end
