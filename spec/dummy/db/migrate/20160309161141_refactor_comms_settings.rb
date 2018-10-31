class RefactorCommsSettings < ActiveRecord::Migration
  def change
    remove_column :spree_users, :comms_settings, :json, default: {}, null: false
    add_column :spree_users, :comms_settings, :json
  end
end
