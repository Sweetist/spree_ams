class CreateSpreeVendorImports < ActiveRecord::Migration
  def change
    create_table :spree_vendor_imports do |t|
      t.integer :company_id
      t.attachment :file
      t.string :encoding
      t.string :delimer
      t.boolean :replace
      t.integer :status
      t.json :verify_result
      t.json :import_result
      t.boolean :proceed
      t.boolean :proceed_verified
      t.text :exception_message

      t.timestamps null: false
    end
    add_index :spree_vendor_imports, :company_id
  end
end
