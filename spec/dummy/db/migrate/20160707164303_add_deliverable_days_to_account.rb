class AddDeliverableDaysToAccount < ActiveRecord::Migration
  def change
  	add_column :spree_accounts, :deliverable_days, :json
  end
end
