class AddPackSizeToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :pack_size, :string
  end
end
