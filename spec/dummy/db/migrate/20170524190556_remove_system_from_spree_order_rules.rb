class RemoveSystemFromSpreeOrderRules < ActiveRecord::Migration
	def self.up
	  remove_column :spree_order_rules, :system
	end
	def self.down
	  add_column :spree_order_rules, :system, :boolean
	end
end
