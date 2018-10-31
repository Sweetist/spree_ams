class ChangeValueOnSpreeOrderRules < ActiveRecord::Migration
  def change
    change_column :spree_order_rules, :value, :integer, null: true
  end
end
