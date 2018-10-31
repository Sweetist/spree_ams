class CreateSpreeCompany < ActiveRecord::Migration
  def up
    create_table :spree_companies do |t|
      t.string   :name,                                null: false
      t.string   :order_cutoff_time
      t.decimal  :delivery_minimum,      default: 0.0
      t.string   :slug
      t.string   :email
      t.string   :time_zone
      t.json     :theme_colors
      t.string   :theme_name
      t.text     :theme_css
      t.json     :settings
      t.json     :invoice_settings
      t.datetime :daily_summary_send_at
      t.integer  :bill_address_id
      t.integer  :ship_address_id
      t.string   :custom_domain,         default: "",  null: false
      t.integer  :access_level,          default: 0,   null: false
      t.string   :internal_company_number
      t.string   :tax_exempt_id
      t.timestamps
    end

    add_column :spree_vendors, :company_id, :integer
    add_column :spree_customers, :company_id, :integer

    add_index :spree_companies, :name
    add_index :spree_companies, :bill_address_id
    add_index :spree_companies, :ship_address_id
    add_index :spree_companies, :access_level
    add_index :spree_companies, :internal_company_number

    vendors = !!Spree::Vendor rescue false
    if vendors
      Spree::Vendor.find_each do |vendor|
        company = Spree::Company.create(
          name: vendor.name,
          order_cutoff_time: vendor.order_cutoff_time,
          delivery_minimum: vendor.delivery_minimum,
          slug: vendor.slug,
          email: vendor.email,
          time_zone: vendor.time_zone,
          theme_colors: vendor.theme_colors,
          theme_name: vendor.theme_name,
          theme_css: vendor.theme_css,
          settings: vendor.settings,
          invoice_settings: vendor.invoice_settings,
          daily_summary_send_at: vendor.daily_summary_send_at,
          bill_address_id: vendor.bill_address_id,
          ship_address_id: vendor.ship_address_id,
          access_level: vendor.access_level
        )
        vendor.update_columns(company_id: company.id)
      end
    end
    customers = !!Spree::Customer rescue false
    if customers
      Spree::Customer.find_each do |customer|
        company = Spree::Company.create(
          name: customer.name,
          email: customer.email,
          time_zone: customer.time_zone,
          bill_address_id: customer.bill_address_id,
          ship_address_id: customer.ship_address_id,
          internal_company_number: customer.spree_account_id,
          tax_exempt_id: customer.tax_exempt_id
        )
        customer.update_columns(company_id: company.id)
      end
    end
  end

  def down
    drop_table :spree_companies
  end
end
