class AddProcessDaysToStandingOrder < ActiveRecord::Migration
  def change
    add_column :spree_standing_orders, :timing_data_process_days, :integer
  end
end
