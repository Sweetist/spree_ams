class AddMemberToSpreeCompanies < ActiveRecord::Migration
  def change
		add_column :spree_companies, :member, :boolean, default: false, null: false
		add_index :spree_companies, :member
  end
end
