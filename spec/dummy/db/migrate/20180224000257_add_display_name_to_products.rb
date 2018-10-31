class AddDisplayNameToProducts < ActiveRecord::Migration
  def change
    add_column :spree_products, :display_name, :string, default: '', null: false
    add_column :spree_products, :default_display_name, :string, default: '', null: false
  end
end
