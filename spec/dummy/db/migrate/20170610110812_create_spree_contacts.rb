class CreateSpreeContacts < ActiveRecord::Migration
  def change
    create_table :spree_contacts do |t|
      t.string   :first_name
      t.string   :last_name
      t.string   :position
      t.string   :company_name
      t.string   :email
      t.string   :phone
      t.string   :addresses
      t.integer  :company_id
      t.integer  :user_id
      t.text     :notes
      t.datetime :invited_at

      t.timestamps null: false
    end

  end
end
