class ModifyNoteModel < ActiveRecord::Migration
  def change
    remove_column :spree_notes, :order_id
    add_column :spree_notes, :account_id, :integer, null: false;
    rename_column :spree_notes, :user_id, :updated_by_id
    add_index :spree_notes, :account_id
  end
end
