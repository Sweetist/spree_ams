class CompanyAccessLevel < ActiveRecord::Migration
  def up
    rename_column :spree_companies, :access_level, :subscription
    change_column :spree_companies, :subscription, :string, default: nil
  end

  def down
    change_column :spree_companies, :subscription, 'integer USING CAST(subscription AS integer)', default: 0
    rename_column :spree_companies, :subscription, :access_level
  end
end
