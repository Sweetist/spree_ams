class AddAccountPaymentIdToPaymentCaptureEvent < ActiveRecord::Migration
  def change
    add_column :spree_payment_capture_events, :account_payment_id, :integer
  end
end
