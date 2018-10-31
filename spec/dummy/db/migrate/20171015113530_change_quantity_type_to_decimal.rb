class ChangeQuantityTypeToDecimal < ActiveRecord::Migration
  def up
    change_column :spree_line_items, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_line_items, :ordered_qty, :decimal, precision: 15, scale: 5
    change_column :spree_line_items, :shipped_qty, :decimal, precision: 15, scale: 5
    change_column :spree_standing_line_items, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_orders, :item_count, :decimal, precision: 15, scale: 5
    change_column :spree_stock_items, :count_on_hand, :decimal, precision: 15, scale: 5
    change_column :spree_stock_movements, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_inventory_units, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_assembly_build_parts, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_assembly_builds, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_ordered_parts, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_ordered_parts, :part_qty, :decimal, precision: 15, scale: 5
    change_column :spree_part_line_items, :quantity, :decimal, precision: 15, scale: 5
    change_column :spree_stock_item_lots, :count, :decimal, precision: 15, scale: 5
    change_column :spree_line_item_lots, :count, :decimal, precision: 15, scale: 5
    change_column :spree_lots, :qty_on_hand, :decimal, precision: 15, scale: 5
    change_column :spree_lots, :qty_sold, :decimal, precision: 15, scale: 5
    change_column :spree_lots, :qty_waste, :decimal, precision: 15, scale: 5
    change_column :spree_assemblies_parts, :count, :decimal, precision: 15, scale: 5
  end
  def down
    change_column :spree_line_items, :quantity, :integer
    change_column :spree_line_items, :ordered_qty, :integer
    change_column :spree_line_items, :shipped_qty, :integer
    change_column :spree_standing_line_items, :quantity, :integer
    change_column :spree_orders, :item_count, :integer
    change_column :spree_stock_items, :count_on_hand, :integer
    change_column :spree_stock_movements, :quantity, :integer
    change_column :spree_inventory_units, :quantity, :integer
    change_column :spree_assembly_build_parts, :quantity, :integer
    change_column :spree_assembly_builds, :quantity, :integer
    change_column :spree_ordered_parts, :quantity, :integer
    change_column :spree_ordered_parts, :part_qty, :integer
    change_column :spree_part_line_items, :quantity, :integer
    change_column :spree_stock_item_lots, :count, :integer
    change_column :spree_line_item_lots, :count, :integer
    change_column :spree_lots, :qty_on_hand, :integer
    change_column :spree_lots, :qty_sold, :integer
    change_column :spree_lots, :qty_waste, :integer
    change_column :spree_assemblies_parts, :count, :integer
  end
end
