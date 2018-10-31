class CreateSpreeBookkeepingDocuments < ActiveRecord::Migration
  def up
    create_table :spree_bookkeeping_documents do |t|
      t.references :printable, polymorphic: true
      t.string :template
      t.string :number
      t.string :firstname
      t.string :lastname
      t.string :email
      t.decimal :total, precision: 12, scale: 2

      t.timestamps null: false
    end
  end

  def down
    drop_table :spree_bookkeeping_documents
  end
end
