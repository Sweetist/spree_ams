class MakeLeadTimeNotNullable < ActiveRecord::Migration
  def change
    change_column_null :spree_variants, :lead_time, false
  end
end
