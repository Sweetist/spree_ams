# This migration comes from spree_product_assembly (originally 20140620223938)
class AddIdToSpreeAssembliesParts < ActiveRecord::Migration
  def up
    add_column :spree_assemblies_parts, :id, :primary_key
  end

  def down
    add_column :spree_assemblies_parts, :id
  end
end
