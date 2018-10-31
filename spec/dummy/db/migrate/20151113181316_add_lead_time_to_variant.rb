class AddLeadTimeToVariant < ActiveRecord::Migration
  def change
    add_column :spree_variants, :lead_time, :integer, default: 1
  end
end
