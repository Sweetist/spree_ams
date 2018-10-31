class AddDescriptionToSpreeOrderRules < ActiveRecord::Migration
  def change
    add_column :spree_order_rules, :description, :string
  end
end
