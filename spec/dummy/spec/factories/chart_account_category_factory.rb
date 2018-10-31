FactoryGirl.define do
  factory :chart_account_category, class: Spree::ChartAccountCategory do
    name 'Income Account'

    factory :income_account_category do
      name 'Income Account'
    end
    factory :expense_account_category do
      name 'Expense Account'
    end
    factory :cogs_account_category do
      name 'Cogs Account'
    end
    factory :asset_account_category do
      name 'Asset Account'
    end
  end


end
