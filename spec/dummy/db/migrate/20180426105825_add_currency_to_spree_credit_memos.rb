class AddCurrencyToSpreeCreditMemos < ActiveRecord::Migration
  def change
    add_column :spree_credit_memos, :currency, :string
  end
end
