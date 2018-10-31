class AddTaxonIdsToSpreeOrderRules < ActiveRecord::Migration
  def change
    add_column :spree_order_rules, :taxon_ids, :string
  end
end
