class CreateSpreePaymentTerms < ActiveRecord::Migration
  def change
    create_table :spree_payment_terms do |t|
      t.string  :name, null: false
      t.text    :description
    end
  end
end
