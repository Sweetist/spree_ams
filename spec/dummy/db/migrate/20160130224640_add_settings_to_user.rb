class AddSettingsToUser < ActiveRecord::Migration
  def up
    add_column :spree_users, :settings, :hstore, default: '', null: false
  end

  def down
    remove_column :spree_users, :settings
  end
end
