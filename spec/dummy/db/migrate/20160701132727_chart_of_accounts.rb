class ChartOfAccounts < ActiveRecord::Migration
  def change
    create_table :spree_chart_account_categories do |t|
      t.string :name, null: false
      t.timestamps null: false
    end
    add_index :spree_chart_account_categories, :name

    create_table :spree_chart_accounts do |t|
      t.string :name, null: false
      t.references :chart_account_category
      t.references :vendor
      t.timestamps null: false
    end
    add_index :spree_chart_accounts, :name
    add_index :spree_chart_accounts, :chart_account_category_id
    add_index :spree_chart_accounts, :vendor_id
    add_index :spree_chart_accounts, [:vendor_id, :name]
    add_index :spree_chart_accounts, [:vendor_id, :chart_account_category_id, :name], name: "index_spreechartaccounts_on_vendorandchartaccountcategoryname"

    reversible do |direction|
      direction.up do
        ["Income Account", "Cost of Goods Sold Account", "Asset Account", "Expense Account", "Shipping Account", "Discount Account"].each {|name| Spree::ChartAccountCategory.create(name: name)}
      end
    end

    add_column :spree_variants, :general_account_id, :integer
    add_column :spree_variants, :income_account_id, :integer
    add_column :spree_variants, :cogs_account_id, :integer
    add_column :spree_variants, :asset_account_id, :integer
    add_column :spree_variants, :expense_account_id, :integer
    add_column :spree_variants, :is_inventory_item, :boolean
    add_column :spree_variants, :is_sales_and_purchase, :boolean

  end
end
