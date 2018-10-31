class AddOriginatorToSpreeCreditTransactions < ActiveRecord::Migration
  def change
    add_reference :spree_credit_transactions, :originator,
                  polymorphic: true,
                  index: { name: 'index_credit_orig_pol' }
    remove_reference :spree_credit_transactions, :creditable,
                     polymorphic: true,
                     index: { name: 'index_creditable_poly' }
  end
end
