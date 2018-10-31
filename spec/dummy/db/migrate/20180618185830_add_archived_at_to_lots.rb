class AddArchivedAtToLots < ActiveRecord::Migration
  def change
    add_column :spree_lots, :archived_at, :datetime
    add_index  :spree_lots, :archived_at
  end
end
