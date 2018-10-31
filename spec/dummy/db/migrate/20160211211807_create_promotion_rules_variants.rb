class CreatePromotionRulesVariants < ActiveRecord::Migration
  def change
    create_table :spree_promotion_rules_variants do |t|
      t.references :variant
      t.references :promotion_rule
    end

    add_index :spree_promotion_rules_variants, [:promotion_rule_id], :name => 'index_promotion_rules_variants_on_promotion_rule_id'
    add_index :spree_promotion_rules_variants, [:variant_id], :name => 'index_promotion_rules_variants_on_variant_id'
  end
end
