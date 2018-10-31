class AddReceiverToShipment < ActiveRecord::Migration
  def change
    add_column :spree_shipments, :receiver_id, :integer
    add_column :spree_shipments, :received_at, :datetime
    add_index :spree_shipments, :receiver_id
  end
end
