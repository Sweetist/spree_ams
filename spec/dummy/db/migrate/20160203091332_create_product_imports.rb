class CreateProductImports < ActiveRecord::Migration
  def change
    create_table :spree_product_imports do |t|
      t.references :vendor
      t.attachment :file
      t.string :encoding
      t.string :delimer
      t.boolean :replace
      t.integer :status
      t.json :verify_result
      t.json :import_result
      t.timestamps null: false
    end
    add_index :spree_product_imports, :vendor_id
  end
end
