# This migration comes from spree_product_assembly (originally 20120316141830)
class NamespaceProductAssemblyForSpreeOne < ActiveRecord::Migration
  def up
    rename_table :assemblies_parts, :spree_assemblies_parts
  end

  def down
    rename_table :spree_assemblies_parts, :assemblies_parts
  end
end
