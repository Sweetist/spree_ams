class AddControllerAttributesToVersions < ActiveRecord::Migration
  def change
    add_column :versions, :controller, :string
    add_column :versions, :action, :string
    add_column :versions, :commit, :string
    add_column :versions, :params, :jsonb
    add_column :versions, :transaction_group_id, :string
  end
end
