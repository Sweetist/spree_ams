class CreateSpreeCreditLineItems < ActiveRecord::Migration
  def change
    create_table :spree_credit_line_items do |t|
      t.references :line_item, index: true
      t.references :credit_memo, index: true
      t.decimal :quantity, precision: 15, scale: 5, default: 0

      t.timestamps null: false
    end
  end
end
