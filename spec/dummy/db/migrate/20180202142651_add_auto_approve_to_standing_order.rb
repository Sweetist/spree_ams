class AddAutoApproveToStandingOrder < ActiveRecord::Migration
  def change
    add_column :spree_standing_orders, :auto_approve, :boolean, default: false
  end
end
