class AddParentToChartAccount < ActiveRecord::Migration
  def change
    add_column :spree_chart_accounts, :parent_id, :integer
    add_index  :spree_chart_accounts, :parent_id
    add_column :spree_chart_accounts, :fully_qualified_name, :string
    add_index  :spree_chart_accounts, :fully_qualified_name
  end
end
