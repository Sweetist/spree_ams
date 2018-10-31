FactoryGirl.define do
  factory :chart_account, class: Spree::ChartAccount do
    name 'Sale of Goods'
    chart_account_category
    vendor { |v| Spree::Company.first || v.association(:vendor) }

    factory :income_account do
      name 'Sales of Product Income'
      chart_account_category {|c| Spree::ChartAccountCategory.where(name: 'Income Account').first || c.association(:income_account_category)}
      vendor { |v| Spree::Company.first || v.association(:vendor) }
    end
    factory :expense_account do
      name 'Materials'
      chart_account_category {|c| Spree::ChartAccountCategory.where(name: 'Expense Account').first || c.association(:expense_account_category)}
      vendor { |v| Spree::Company.first || v.association(:vendor) }
    end
    factory :cogs_account do
      name 'Cost of Goods Sold'
      chart_account_category {|c| Spree::ChartAccountCategory.where(name: 'Cogs Account').first || c.association(:cogs_account_category)}
      vendor { |v| Spree::Company.first || v.association(:vendor) }
    end
    factory :asset_account do
      name 'Inventory Asset'
      chart_account_category {|c| Spree::ChartAccountCategory.where(name: 'Asset Account').first || c.association(:asset_account_category)}
      vendor { |v| Spree::Company.first || v.association(:vendor) }
    end

  end
end
