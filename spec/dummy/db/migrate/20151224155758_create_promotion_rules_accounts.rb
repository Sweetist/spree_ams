class CreatePromotionRulesAccounts < ActiveRecord::Migration
  def change
    create_table :spree_promotion_rules_accounts do |t|
      t.references :account
      t.references :promotion_rule
    end

    add_index :spree_promotion_rules_accounts, [:promotion_rule_id], :name => 'index_promotion_rules_accounts_on_promotion_rule_id'
    add_index :spree_promotion_rules_accounts, [:account_id], :name => 'index_promotion_rules_accounts_on_account_id'
  end
end
