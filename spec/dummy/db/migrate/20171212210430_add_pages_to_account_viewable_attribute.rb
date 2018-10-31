class AddPagesToAccountViewableAttribute < ActiveRecord::Migration
  def change
    add_column :spree_customer_viewable_attributes, :pages, :jsonb
  end
end
