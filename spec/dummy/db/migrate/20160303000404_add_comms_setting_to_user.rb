class AddCommsSettingToUser < ActiveRecord::Migration
  
  def up
    add_column :spree_users, :comms_settings, :json, default: {}, null: false
  end

  def down
    remove_column :spree_users, :comms_settings
  end

end
