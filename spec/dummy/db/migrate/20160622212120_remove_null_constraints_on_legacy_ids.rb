class RemoveNullConstraintsOnLegacyIds < ActiveRecord::Migration
  def change
    change_column_null(:spree_customer_types, :vendor_lid, true)
    change_column_null(:spree_reps, :vendor_lid, true)
  end
end
