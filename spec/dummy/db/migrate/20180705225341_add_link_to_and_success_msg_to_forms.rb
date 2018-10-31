class AddLinkToAndSuccessMsgToForms < ActiveRecord::Migration
  def change
    add_column :spree_forms, :link_to_text, :string
    add_column :spree_forms, :success_message, :text
  end
end
