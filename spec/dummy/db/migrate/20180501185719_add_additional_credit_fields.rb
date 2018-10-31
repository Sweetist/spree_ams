class AddAdditionalCreditFields < ActiveRecord::Migration
  def change
    remove_column :spree_credit_line_items, :line_item_id,        :integer
    add_column    :spree_credit_line_items, :variant_id,          :integer, null: false
    add_column    :spree_credit_line_items, :item_name,           :string,  null: false
    add_column    :spree_credit_line_items, :price,               :decimal, precision: 15, scale: 5, default: 0, null: false
    add_column    :spree_credit_line_items, :txn_class_id,        :integer
    add_column    :spree_credit_line_items, :tax_category_id,     :integer
    add_column    :spree_credit_line_items, :lot_number,          :string
    add_column    :spree_credit_line_items, :currency,            :string

    add_index     :spree_credit_line_items, :variant_id
    add_index     :spree_credit_line_items, :txn_class_id
    add_index     :spree_credit_line_items, :tax_category_id
    add_index     :spree_credit_line_items, :currency

    add_column    :spree_credit_memos,      :txn_class_id,        :integer
    add_column    :spree_credit_memos,      :shipping_method_id,  :integer
    add_column    :spree_credit_memos,      :stock_location_id,   :integer
    add_column    :spree_credit_memos,      :note,                :text

    add_index     :spree_credit_memos,      :txn_class_id
    add_index     :spree_credit_memos,      :shipping_method_id
    add_index     :spree_credit_memos,      :stock_location_id
  end
end
