class CreateSpreeOrderRules < ActiveRecord::Migration
  def change
    create_table :spree_order_rules do |t|
      t.integer :vendor_id, index: true, foreign_key: true
      t.boolean :active, default: true, null: false
      t.integer :rule_type, null: false
      t.integer :value, null: false

      t.timestamps null: false
    end
  end
end
