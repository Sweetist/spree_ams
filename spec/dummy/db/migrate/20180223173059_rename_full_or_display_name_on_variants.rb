class RenameFullOrDisplayNameOnVariants < ActiveRecord::Migration
  def change
    rename_column :spree_variants, :full_or_display_name, :default_display_name
    rename_column :spree_accounts, :full_or_display_name, :default_display_name
  end
end
