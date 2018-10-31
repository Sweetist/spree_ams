class AddSystemToSpreeOrderRules < ActiveRecord::Migration
  def change
    add_column :spree_order_rules, :system, :boolean, default: false, null: false
  end
end
