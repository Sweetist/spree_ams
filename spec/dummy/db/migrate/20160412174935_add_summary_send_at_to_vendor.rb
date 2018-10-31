class AddSummarySendAtToVendor < ActiveRecord::Migration
  def change
    add_column :spree_vendors, :daily_summary_send_at, :datetime
    add_index :spree_vendors, :daily_summary_send_at
  end
end
