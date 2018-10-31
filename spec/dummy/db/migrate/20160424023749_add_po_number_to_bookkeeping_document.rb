class AddPoNumberToBookkeepingDocument < ActiveRecord::Migration
  def change
    add_column :spree_bookkeeping_documents, :po_number, :string
  end
end
