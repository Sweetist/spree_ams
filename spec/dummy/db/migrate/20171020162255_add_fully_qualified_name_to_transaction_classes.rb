class AddFullyQualifiedNameToTransactionClasses < ActiveRecord::Migration
  def change
    add_column :spree_transaction_classes, :fully_qualified_name, :string
    add_index  :spree_transaction_classes, :fully_qualified_name
  end
end
