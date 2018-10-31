class AddFullyQualifiedNameToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :fully_qualified_name, :string
    add_index :spree_variants, :fully_qualified_name
  end
end
