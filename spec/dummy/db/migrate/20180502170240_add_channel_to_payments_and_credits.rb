class AddChannelToPaymentsAndCredits < ActiveRecord::Migration
  def change
    add_column :spree_account_payments, :channel, :string, default: 'sweet', null: false
    add_column :spree_payments, :channel, :string, default: 'sweet', null: false
    add_column :spree_credit_memos, :channel, :string, default: 'sweet', null: false

    add_index  :spree_account_payments, :channel
    add_index  :spree_payments, :channel
    add_index  :spree_credit_memos, :channel
  end
end
