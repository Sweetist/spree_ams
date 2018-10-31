class CreateEmailTemplates < ActiveRecord::Migration
  def up
    create_table :spree_email_templates do |t|
      t.string :subject
      t.string :from
      t.string :bcc
      t.string :cc
      t.string :slug,     :null => false
			t.string :file_path,:null => false
      t.text :body,       :null => false
      t.text :template,   :null => false
			t.integer :vendor_id
    end

    add_index :spree_email_templates, :slug
		add_index :spree_email_templates, :vendor_id

  end

  def self.down
    drop_table :spree_email_templates
  end

end
