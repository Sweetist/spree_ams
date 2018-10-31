class RemoveUpdatedByFromSpreeNote < ActiveRecord::Migration
  def change
  	remove_column :spree_notes, :updated_by_id, :integer
  end
end
