class AddTextOptionsToVariants < ActiveRecord::Migration
  def change
    add_column :spree_variants, :text_options, :string
    add_column :spree_line_items, :text_option, :string
  end
end
