class CreateSpreeTransactionClass < ActiveRecord::Migration
  def change
    create_table :spree_transaction_classes do |t|
      t.string :name
      t.integer :parent_id
      t.integer :vendor_id
    end
  end
end
