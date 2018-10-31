class CreateMasterCreditCards < ActiveRecord::Migration
  def change
    create_table :spree_master_credit_cards do |t|
      t.integer :company_id
      t.integer :credit_cards_id
      t.string :month
      t.string :year
      t.string :cc_type
      t.string :last_digits
      t.integer :address_id
      t.string :verification_value
      t.string :gateway_customer_profile_id
      t.string :gateway_payment_profile_id
      t.string :name
      t.timestamps null: false
    end
  end
end
