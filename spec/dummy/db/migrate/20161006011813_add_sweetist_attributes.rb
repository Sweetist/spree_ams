class AddSweetistAttributes < ActiveRecord::Migration
  def change
    add_column :spree_accounts, :custom_attrs, :jsonb
    add_column :spree_orders, :custom_attrs, :jsonb
    add_column :spree_variants, :custom_attrs, :jsonb
  end
end
