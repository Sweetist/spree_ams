class ChangeAccountViewableRecalculatingType < ActiveRecord::Migration
  def up
    change_column :spree_account_viewable_products, :recalculating, 'integer USING CAST(recalculating AS integer)'
  end
  def down
  end
end
