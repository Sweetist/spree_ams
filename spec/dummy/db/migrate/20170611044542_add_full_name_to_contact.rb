class AddFullNameToContact < ActiveRecord::Migration
  def change
    add_column :spree_contacts, :full_name, :string
    add_index :spree_contacts, :full_name
  end
end
