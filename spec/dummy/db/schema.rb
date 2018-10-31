# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20181010212246) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "hstore"
  enable_extension "pg_stat_statements"

  create_table "commontator_comments", force: :cascade do |t|
    t.string   "creator_type"
    t.integer  "creator_id"
    t.string   "editor_type"
    t.integer  "editor_id"
    t.integer  "thread_id",                              null: false
    t.text     "body",                                   null: false
    t.datetime "deleted_at"
    t.integer  "cached_votes_up",   default: 0
    t.integer  "cached_votes_down", default: 0
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "share_level",       default: "internal"
  end

  add_index "commontator_comments", ["cached_votes_down"], name: "index_commontator_comments_on_cached_votes_down", using: :btree
  add_index "commontator_comments", ["cached_votes_up"], name: "index_commontator_comments_on_cached_votes_up", using: :btree
  add_index "commontator_comments", ["creator_id", "creator_type", "thread_id"], name: "index_commontator_comments_on_c_id_and_c_type_and_t_id", using: :btree
  add_index "commontator_comments", ["thread_id", "created_at"], name: "index_commontator_comments_on_thread_id_and_created_at", using: :btree

  create_table "commontator_subscriptions", force: :cascade do |t|
    t.string   "subscriber_type", null: false
    t.integer  "subscriber_id",   null: false
    t.integer  "thread_id",       null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "commontator_subscriptions", ["subscriber_id", "subscriber_type", "thread_id"], name: "index_commontator_subscriptions_on_s_id_and_s_type_and_t_id", unique: true, using: :btree
  add_index "commontator_subscriptions", ["thread_id"], name: "index_commontator_subscriptions_on_thread_id", using: :btree

  create_table "commontator_threads", force: :cascade do |t|
    t.string   "commontable_type"
    t.integer  "commontable_id"
    t.datetime "closed_at"
    t.string   "closer_type"
    t.integer  "closer_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "commontator_threads", ["commontable_id", "commontable_type"], name: "index_commontator_threads_on_c_id_and_c_type", unique: true, using: :btree

  create_table "friendly_id_slugs", force: :cascade do |t|
    t.string   "slug",                      null: false
    t.integer  "sluggable_id",              null: false
    t.string   "sluggable_type", limit: 50
    t.string   "scope"
    t.datetime "created_at"
    t.datetime "deleted_at"
  end

  add_index "friendly_id_slugs", ["deleted_at"], name: "index_friendly_id_slugs_on_deleted_at", using: :btree
  add_index "friendly_id_slugs", ["slug", "sluggable_type", "scope"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type_and_scope", unique: true, using: :btree
  add_index "friendly_id_slugs", ["slug", "sluggable_type"], name: "index_friendly_id_slugs_on_slug_and_sluggable_type", using: :btree
  add_index "friendly_id_slugs", ["sluggable_id"], name: "index_friendly_id_slugs_on_sluggable_id", using: :btree
  add_index "friendly_id_slugs", ["sluggable_type"], name: "index_friendly_id_slugs_on_sluggable_type", using: :btree

  create_table "inventory_change_histories", force: :cascade do |t|
    t.integer  "stock_item_id",                                  null: false
    t.integer  "stock_location_id",                              null: false
    t.integer  "user_id"
    t.integer  "company_id"
    t.integer  "variant_id",                                     null: false
    t.string   "action",                                         null: false
    t.integer  "customer_id"
    t.string   "reason"
    t.integer  "customer_type_id"
    t.string   "pack_size"
    t.integer  "originator_id",                                  null: false
    t.string   "originator_type",                                null: false
    t.datetime "originator_created_at",                          null: false
    t.datetime "originator_updated_at"
    t.string   "originator_number",                              null: false
    t.string   "item_variant_name",                              null: false
    t.string   "item_variant_sku",                               null: false
    t.string   "stock_location_name",                            null: false
    t.string   "customer_name"
    t.string   "customer_type_name"
    t.integer  "source_location_id"
    t.string   "source_location_name"
    t.datetime "created_at",                                     null: false
    t.datetime "updated_at",                                     null: false
    t.integer  "stock_movement_id"
    t.decimal  "quantity",              precision: 15, scale: 5
    t.decimal  "quantity_on_hand",      precision: 15, scale: 5
  end

  create_table "spree_account_payment_methods", force: :cascade do |t|
    t.integer  "payment_method_id"
    t.integer  "account_id"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  create_table "spree_account_payments", force: :cascade do |t|
    t.decimal  "amount",               precision: 15, scale: 5
    t.integer  "vendor_id"
    t.integer  "account_id"
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
    t.integer  "source_id"
    t.string   "source_type"
    t.integer  "payment_method_id"
    t.string   "state"
    t.string   "response_code"
    t.string   "avs_response"
    t.string   "currency"
    t.string   "number"
    t.string   "cvv_response_code"
    t.string   "cvv_response_message"
    t.text     "memo"
    t.string   "txn_id"
    t.decimal  "credit_amount",        precision: 15, scale: 5, default: 0
    t.decimal  "credit_to_apply",      precision: 15, scale: 5, default: 0
    t.string   "last_ip_address"
    t.string   "channel",                                       default: "sweet", null: false
    t.datetime "payment_date"
  end

  add_index "spree_account_payments", ["account_id"], name: "index_spree_account_payments_on_account_id", using: :btree
  add_index "spree_account_payments", ["channel"], name: "index_spree_account_payments_on_channel", using: :btree
  add_index "spree_account_payments", ["payment_date"], name: "index_spree_account_payments_on_payment_date", using: :btree
  add_index "spree_account_payments", ["vendor_id"], name: "index_spree_account_payments_on_vendor_id", using: :btree

  create_table "spree_account_viewable_products", force: :cascade do |t|
    t.integer "account_id",                                               null: false
    t.integer "product_id",                                               null: false
    t.decimal "max_price",       precision: 10, scale: 2
    t.decimal "min_price",       precision: 10, scale: 2
    t.boolean "visible",                                  default: false
    t.integer "recalculating"
    t.json    "variants_prices"
    t.text    "promotion_ids",                            default: [],                 array: true
  end

  add_index "spree_account_viewable_products", ["account_id"], name: "index_spree_account_viewable_products_on_account_id", using: :btree
  add_index "spree_account_viewable_products", ["product_id", "account_id"], name: "viewable_products_on_product_id_and_account_id", using: :btree
  add_index "spree_account_viewable_products", ["product_id"], name: "index_spree_account_viewable_products_on_product_id", using: :btree
  add_index "spree_account_viewable_products", ["recalculating"], name: "index_spree_account_viewable_products_on_recalculating", using: :btree
  add_index "spree_account_viewable_products", ["visible"], name: "index_spree_account_viewable_products_on_visible", using: :btree

  create_table "spree_account_viewable_variants", force: :cascade do |t|
    t.integer "account_id",                 null: false
    t.integer "variant_id",                 null: false
    t.boolean "visible"
    t.decimal "price",         default: 0,  null: false
    t.text    "promotion_ids", default: [],              array: true
    t.integer "recalculating"
    t.integer "price_list_id"
  end

  add_index "spree_account_viewable_variants", ["account_id"], name: "index_spree_account_viewable_variants_on_account_id", using: :btree
  add_index "spree_account_viewable_variants", ["price"], name: "index_spree_account_viewable_variants_on_price", using: :btree
  add_index "spree_account_viewable_variants", ["price_list_id"], name: "index_spree_account_viewable_variants_on_price_list_id", using: :btree
  add_index "spree_account_viewable_variants", ["recalculating"], name: "index_spree_account_viewable_variants_on_recalculating", using: :btree
  add_index "spree_account_viewable_variants", ["variant_id"], name: "index_spree_account_viewable_variants_on_variant_id", using: :btree
  add_index "spree_account_viewable_variants", ["visible"], name: "index_spree_account_viewable_variants_on_visible", using: :btree

  create_table "spree_accounts", force: :cascade do |t|
    t.decimal  "balance",                                               default: 0,       null: false
    t.string   "status"
    t.datetime "created_at",                                                              null: false
    t.datetime "updated_at",                                                              null: false
    t.string   "number"
    t.integer  "default_shipping_method_id"
    t.integer  "payment_terms_id"
    t.string   "name"
    t.datetime "active_date"
    t.datetime "inactive_date"
    t.string   "inactive_reason"
    t.integer  "rep_id"
    t.integer  "customer_type_id"
    t.integer  "vendor_id"
    t.integer  "customer_id"
    t.json     "deliverable_days"
    t.integer  "shipping_group_id"
    t.string   "fully_qualified_name"
    t.string   "email"
    t.integer  "parent_id"
    t.string   "tax_exempt_id"
    t.jsonb    "custom_attrs"
    t.string   "send_mail"
    t.integer  "primary_cust_contact_id"
    t.integer  "primary_vendor_contact_id"
    t.boolean  "standing_orders_permission",                            default: true
    t.integer  "default_stock_location_id"
    t.boolean  "default_shipping_method_only",                          default: false,   null: false
    t.boolean  "send_purchase_orders_emails",                           default: false
    t.integer  "default_txn_class_id"
    t.boolean  "taxable",                                               default: false
    t.string   "display_name"
    t.string   "default_display_name"
    t.string   "shipment_email"
    t.string   "channel",                                               default: "sweet", null: false
    t.decimal  "available_credit",             precision: 15, scale: 5, default: 0
    t.decimal  "external_balance",             precision: 15, scale: 5, default: 0,       null: false
    t.decimal  "external_credit",              precision: 15, scale: 5, default: 0,       null: false
    t.decimal  "credit_limit",                 precision: 15, scale: 5
    t.integer  "tax_category_id"
    t.datetime "last_ordered_at"
    t.datetime "last_invoice_date"
    t.integer  "bill_address_id"
    t.integer  "default_ship_address_id"
  end

  add_index "spree_accounts", ["available_credit"], name: "index_spree_accounts_on_available_credit", using: :btree
  add_index "spree_accounts", ["balance"], name: "index_spree_accounts_on_balance", using: :btree
  add_index "spree_accounts", ["bill_address_id"], name: "index_spree_accounts_on_bill_address_id", using: :btree
  add_index "spree_accounts", ["channel"], name: "index_spree_accounts_on_channel", using: :btree
  add_index "spree_accounts", ["customer_type_id"], name: "index_spree_accounts_on_customer_type_id", using: :btree
  add_index "spree_accounts", ["default_display_name"], name: "index_spree_accounts_on_default_display_name", using: :btree
  add_index "spree_accounts", ["default_ship_address_id"], name: "index_spree_accounts_on_default_ship_address_id", using: :btree
  add_index "spree_accounts", ["default_shipping_method_id"], name: "index_spree_accounts_on_default_shipping_method_id", using: :btree
  add_index "spree_accounts", ["default_txn_class_id"], name: "index_spree_accounts_on_default_txn_class_id", using: :btree
  add_index "spree_accounts", ["external_balance"], name: "index_spree_accounts_on_external_balance", using: :btree
  add_index "spree_accounts", ["external_credit"], name: "index_spree_accounts_on_external_credit", using: :btree
  add_index "spree_accounts", ["fully_qualified_name"], name: "index_spree_accounts_on_fully_qualified_name", using: :btree
  add_index "spree_accounts", ["inactive_date"], name: "index_spree_accounts_on_inactive_date", using: :btree
  add_index "spree_accounts", ["last_invoice_date"], name: "index_spree_accounts_on_last_invoice_date", using: :btree
  add_index "spree_accounts", ["last_ordered_at"], name: "index_spree_accounts_on_last_ordered_at", using: :btree
  add_index "spree_accounts", ["name"], name: "index_spree_accounts_on_name", using: :btree
  add_index "spree_accounts", ["parent_id"], name: "index_spree_accounts_on_parent_id", using: :btree
  add_index "spree_accounts", ["payment_terms_id"], name: "index_spree_accounts_on_payment_terms_id", using: :btree
  add_index "spree_accounts", ["rep_id"], name: "index_spree_accounts_on_rep_id", using: :btree
  add_index "spree_accounts", ["shipping_group_id"], name: "index_spree_accounts_on_shipping_group_id", using: :btree
  add_index "spree_accounts", ["tax_category_id"], name: "index_spree_accounts_on_tax_category_id", using: :btree
  add_index "spree_accounts", ["tax_exempt_id"], name: "index_spree_accounts_on_tax_exempt_id", using: :btree

  create_table "spree_addresses", force: :cascade do |t|
    t.string   "firstname"
    t.string   "lastname"
    t.string   "address1"
    t.string   "address2"
    t.string   "city"
    t.string   "zipcode"
    t.string   "phone"
    t.string   "state_name"
    t.string   "alternative_phone"
    t.string   "company"
    t.integer  "state_id"
    t.integer  "country_id"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.integer  "account_id"
    t.string   "addr_type"
  end

  add_index "spree_addresses", ["account_id"], name: "index_spree_addresses_on_account_id", using: :btree
  add_index "spree_addresses", ["addr_type"], name: "index_spree_addresses_on_addr_type", using: :btree
  add_index "spree_addresses", ["country_id"], name: "index_spree_addresses_on_country_id", using: :btree
  add_index "spree_addresses", ["firstname"], name: "index_addresses_on_firstname", using: :btree
  add_index "spree_addresses", ["lastname"], name: "index_addresses_on_lastname", using: :btree
  add_index "spree_addresses", ["state_id"], name: "index_spree_addresses_on_state_id", using: :btree

  create_table "spree_adjustments", force: :cascade do |t|
    t.integer  "source_id"
    t.string   "source_type"
    t.integer  "adjustable_id"
    t.string   "adjustable_type"
    t.decimal  "amount",          precision: 10, scale: 2
    t.string   "label"
    t.boolean  "mandatory"
    t.boolean  "eligible",                                 default: true
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
    t.string   "state"
    t.integer  "order_id",                                                 null: false
    t.boolean  "included",                                 default: false
  end

  add_index "spree_adjustments", ["adjustable_id", "adjustable_type"], name: "index_spree_adjustments_on_adjustable_id_and_adjustable_type", using: :btree
  add_index "spree_adjustments", ["adjustable_id"], name: "index_adjustments_on_order_id", using: :btree
  add_index "spree_adjustments", ["eligible"], name: "index_spree_adjustments_on_eligible", using: :btree
  add_index "spree_adjustments", ["order_id"], name: "index_spree_adjustments_on_order_id", using: :btree
  add_index "spree_adjustments", ["source_id", "source_type"], name: "index_spree_adjustments_on_source_id_and_source_type", using: :btree

  create_table "spree_applied_credits", force: :cascade do |t|
    t.integer  "credit_memo_id"
    t.integer  "account_payment_id"
    t.decimal  "amount",             precision: 15, scale: 5, default: 0, null: false
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
  end

  add_index "spree_applied_credits", ["account_payment_id"], name: "index_spree_applied_credits_on_account_payment_id", using: :btree
  add_index "spree_applied_credits", ["credit_memo_id"], name: "index_spree_applied_credits_on_credit_memo_id", using: :btree

  create_table "spree_assemblies_parts", force: :cascade do |t|
    t.integer "assembly_id",                                                     null: false
    t.integer "part_id",                                                         null: false
    t.decimal "count",                      precision: 15, scale: 5, default: 1, null: false
    t.boolean "variant_selection_deferred"
  end

  create_table "spree_assembly_build_parts", force: :cascade do |t|
    t.integer  "build_id"
    t.decimal  "quantity",          precision: 15, scale: 5
    t.integer  "variant_id"
    t.integer  "stock_item_lot_id"
    t.integer  "stock_item_id"
    t.datetime "created_at",                                 null: false
    t.datetime "updated_at",                                 null: false
  end

  add_index "spree_assembly_build_parts", ["build_id"], name: "index_spree_assembly_build_parts_on_build_id", using: :btree
  add_index "spree_assembly_build_parts", ["variant_id"], name: "index_spree_assembly_build_parts_on_variant_id", using: :btree

  create_table "spree_assembly_builds", force: :cascade do |t|
    t.integer  "assembly_id",                                      null: false
    t.decimal  "quantity",    precision: 15, scale: 5, default: 0, null: false
    t.datetime "created_at",                                       null: false
    t.datetime "updated_at",                                       null: false
  end

  add_index "spree_assembly_builds", ["assembly_id"], name: "index_spree_assembly_builds_on_assembly_id", using: :btree

  create_table "spree_assets", force: :cascade do |t|
    t.integer  "viewable_id"
    t.string   "viewable_type"
    t.integer  "attachment_width"
    t.integer  "attachment_height"
    t.integer  "attachment_file_size"
    t.integer  "position"
    t.string   "attachment_content_type"
    t.string   "attachment_file_name"
    t.string   "type",                    limit: 75
    t.datetime "attachment_updated_at"
    t.text     "alt"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "spree_assets", ["viewable_id"], name: "index_assets_on_viewable_id", using: :btree
  add_index "spree_assets", ["viewable_type", "type"], name: "index_assets_on_viewable_type_and_type", using: :btree

  create_table "spree_balance_transactions", force: :cascade do |t|
    t.integer  "account_id",                                           null: false
    t.decimal  "amount",          precision: 15, scale: 5, default: 0, null: false
    t.integer  "originator_id",                                        null: false
    t.string   "originator_type",                                      null: false
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
  end

  add_index "spree_balance_transactions", ["account_id"], name: "index_spree_balance_transactions_on_account_id", using: :btree
  add_index "spree_balance_transactions", ["originator_type", "originator_id"], name: "index_balance_orig_pol", using: :btree

  create_table "spree_bookkeeping_documents", force: :cascade do |t|
    t.integer  "printable_id"
    t.string   "printable_type"
    t.string   "template"
    t.string   "number"
    t.string   "firstname"
    t.string   "lastname"
    t.string   "email"
    t.decimal  "total",          precision: 12, scale: 2
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.string   "po_number"
  end

  add_index "spree_bookkeeping_documents", ["printable_id", "printable_type"], name: "index_spree_bookkeeping_documents_on_printable", using: :btree
  add_index "spree_bookkeeping_documents", ["printable_id"], name: "index_spree_bookkeeping_documents_on_printable_id", using: :btree
  add_index "spree_bookkeeping_documents", ["printable_type"], name: "index_spree_bookkeeping_documents_on_printable_type", using: :btree

  create_table "spree_calculators", force: :cascade do |t|
    t.string   "type"
    t.integer  "calculable_id"
    t.string   "calculable_type"
    t.datetime "created_at",      null: false
    t.datetime "updated_at",      null: false
    t.text     "preferences"
    t.datetime "deleted_at"
  end

  add_index "spree_calculators", ["calculable_id", "calculable_type"], name: "index_spree_calculators_on_calculable_id_and_calculable_type", using: :btree
  add_index "spree_calculators", ["deleted_at"], name: "index_spree_calculators_on_deleted_at", using: :btree
  add_index "spree_calculators", ["id", "type"], name: "index_spree_calculators_on_id_and_type", using: :btree

  create_table "spree_chart_account_categories", force: :cascade do |t|
    t.string   "name",       null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "spree_chart_account_categories", ["name"], name: "index_spree_chart_account_categories_on_name", using: :btree

  create_table "spree_chart_accounts", force: :cascade do |t|
    t.string   "name",                      null: false
    t.integer  "chart_account_category_id"
    t.integer  "vendor_id"
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.integer  "parent_id"
    t.string   "fully_qualified_name"
  end

  add_index "spree_chart_accounts", ["chart_account_category_id"], name: "index_spree_chart_accounts_on_chart_account_category_id", using: :btree
  add_index "spree_chart_accounts", ["fully_qualified_name"], name: "index_spree_chart_accounts_on_fully_qualified_name", using: :btree
  add_index "spree_chart_accounts", ["name"], name: "index_spree_chart_accounts_on_name", using: :btree
  add_index "spree_chart_accounts", ["parent_id"], name: "index_spree_chart_accounts_on_parent_id", using: :btree
  add_index "spree_chart_accounts", ["vendor_id", "chart_account_category_id", "name"], name: "index_spreechartaccounts_on_vendorandchartaccountcategoryname", using: :btree
  add_index "spree_chart_accounts", ["vendor_id", "name"], name: "index_spree_chart_accounts_on_vendor_id_and_name", using: :btree
  add_index "spree_chart_accounts", ["vendor_id"], name: "index_spree_chart_accounts_on_vendor_id", using: :btree

  create_table "spree_cities", force: :cascade do |t|
    t.string   "name"
    t.integer  "state_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "spree_cities", ["state_id"], name: "index_spree_cities_on_state_id", using: :btree

  create_table "spree_companies", force: :cascade do |t|
    t.string   "name",                                    null: false
    t.string   "order_cutoff_time"
    t.decimal  "delivery_minimum",        default: 0
    t.string   "slug"
    t.string   "email"
    t.string   "time_zone"
    t.json     "theme_colors"
    t.string   "theme_name"
    t.text     "theme_css"
    t.json     "settings"
    t.json     "invoice_settings"
    t.datetime "daily_summary_send_at"
    t.integer  "bill_address_id"
    t.integer  "ship_address_id"
    t.string   "custom_domain",           default: "",    null: false
    t.string   "subscription",                            null: false
    t.string   "internal_company_number"
    t.string   "tax_exempt_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.datetime "inactive_date"
    t.string   "inactive_reason"
    t.datetime "active_date"
    t.boolean  "member",                  default: false, null: false
    t.json     "carriers"
  end

  add_index "spree_companies", ["bill_address_id"], name: "index_spree_companies_on_bill_address_id", using: :btree
  add_index "spree_companies", ["inactive_date"], name: "index_spree_companies_on_inactive_date", using: :btree
  add_index "spree_companies", ["internal_company_number"], name: "index_spree_companies_on_internal_company_number", using: :btree
  add_index "spree_companies", ["member"], name: "index_spree_companies_on_member", using: :btree
  add_index "spree_companies", ["name"], name: "index_spree_companies_on_name", using: :btree
  add_index "spree_companies", ["ship_address_id"], name: "index_spree_companies_on_ship_address_id", using: :btree
  add_index "spree_companies", ["subscription"], name: "index_spree_companies_on_subscription", using: :btree

  create_table "spree_contact_accounts", force: :cascade do |t|
    t.integer  "account_id", null: false
    t.integer  "contact_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "spree_contact_accounts", ["account_id"], name: "index_spree_contact_accounts_on_account_id", using: :btree
  add_index "spree_contact_accounts", ["contact_id"], name: "index_spree_contact_accounts_on_contact_id", using: :btree

  create_table "spree_contacts", force: :cascade do |t|
    t.string   "first_name"
    t.string   "last_name"
    t.string   "position"
    t.string   "company_name"
    t.string   "email"
    t.string   "phone"
    t.string   "addresses"
    t.integer  "company_id"
    t.integer  "user_id"
    t.text     "notes"
    t.datetime "invited_at"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
    t.string   "full_name"
  end

  add_index "spree_contacts", ["full_name"], name: "index_spree_contacts_on_full_name", using: :btree

  create_table "spree_countries", force: :cascade do |t|
    t.string   "iso_name"
    t.string   "iso"
    t.string   "iso3"
    t.string   "name"
    t.integer  "numcode"
    t.boolean  "states_required", default: false
    t.datetime "updated_at"
  end

  add_index "spree_countries", ["iso"], name: "index_spree_countries_on_iso", using: :btree
  add_index "spree_countries", ["iso3"], name: "index_spree_countries_on_iso3", using: :btree
  add_index "spree_countries", ["iso_name"], name: "index_spree_countries_on_iso_name", using: :btree
  add_index "spree_countries", ["name"], name: "index_spree_countries_on_name", using: :btree

  create_table "spree_credit_cards", force: :cascade do |t|
    t.string   "month"
    t.string   "year"
    t.string   "cc_type"
    t.string   "last_digits"
    t.integer  "address_id"
    t.string   "gateway_customer_profile_id"
    t.string   "gateway_payment_profile_id"
    t.datetime "created_at",                                  null: false
    t.datetime "updated_at",                                  null: false
    t.string   "name"
    t.integer  "user_id"
    t.integer  "payment_method_id"
    t.boolean  "default",                     default: false, null: false
    t.integer  "account_id"
    t.datetime "deleted_at"
  end

  add_index "spree_credit_cards", ["account_id"], name: "index_spree_credit_cards_on_account_id", using: :btree
  add_index "spree_credit_cards", ["address_id"], name: "index_spree_credit_cards_on_address_id", using: :btree
  add_index "spree_credit_cards", ["deleted_at"], name: "index_spree_credit_cards_on_deleted_at", using: :btree
  add_index "spree_credit_cards", ["gateway_customer_profile_id"], name: "index_spree_credit_cards_on_gateway_customer_profile_id", using: :btree
  add_index "spree_credit_cards", ["gateway_payment_profile_id"], name: "index_spree_credit_cards_on_gateway_payment_profile_id", using: :btree
  add_index "spree_credit_cards", ["payment_method_id"], name: "index_spree_credit_cards_on_payment_method_id", using: :btree
  add_index "spree_credit_cards", ["user_id"], name: "index_spree_credit_cards_on_user_id", using: :btree

  create_table "spree_credit_line_items", force: :cascade do |t|
    t.integer  "credit_memo_id"
    t.decimal  "quantity",        precision: 15, scale: 5, default: 0
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.integer  "variant_id",                                           null: false
    t.string   "item_name",                                            null: false
    t.decimal  "price",           precision: 15, scale: 5, default: 0, null: false
    t.integer  "txn_class_id"
    t.integer  "tax_category_id"
    t.string   "lot_number"
    t.string   "currency"
    t.integer  "position",                                 default: 0, null: false
  end

  add_index "spree_credit_line_items", ["credit_memo_id"], name: "index_spree_credit_line_items_on_credit_memo_id", using: :btree
  add_index "spree_credit_line_items", ["currency"], name: "index_spree_credit_line_items_on_currency", using: :btree
  add_index "spree_credit_line_items", ["position"], name: "index_spree_credit_line_items_on_position", using: :btree
  add_index "spree_credit_line_items", ["tax_category_id"], name: "index_spree_credit_line_items_on_tax_category_id", using: :btree
  add_index "spree_credit_line_items", ["txn_class_id"], name: "index_spree_credit_line_items_on_txn_class_id", using: :btree
  add_index "spree_credit_line_items", ["variant_id"], name: "index_spree_credit_line_items_on_variant_id", using: :btree

  create_table "spree_credit_memos", force: :cascade do |t|
    t.integer  "vendor_id"
    t.integer  "account_id"
    t.string   "number"
    t.decimal  "total",                precision: 15, scale: 5, default: 0
    t.decimal  "item_total",           precision: 15, scale: 5, default: 0
    t.decimal  "additional_tax_total", precision: 15, scale: 5, default: 0
    t.decimal  "included_tax_total",   precision: 15, scale: 5, default: 0
    t.decimal  "shipment_total",       precision: 15, scale: 5, default: 0
    t.decimal  "amount_remaining",     precision: 15, scale: 5, default: 0
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
    t.string   "currency"
    t.integer  "txn_class_id"
    t.integer  "shipping_method_id"
    t.integer  "stock_location_id"
    t.text     "note"
    t.string   "channel",                                       default: "sweet", null: false
    t.datetime "txn_date",                                                        null: false
  end

  add_index "spree_credit_memos", ["account_id"], name: "index_spree_credit_memos_on_account_id", using: :btree
  add_index "spree_credit_memos", ["channel"], name: "index_spree_credit_memos_on_channel", using: :btree
  add_index "spree_credit_memos", ["shipping_method_id"], name: "index_spree_credit_memos_on_shipping_method_id", using: :btree
  add_index "spree_credit_memos", ["stock_location_id"], name: "index_spree_credit_memos_on_stock_location_id", using: :btree
  add_index "spree_credit_memos", ["txn_class_id"], name: "index_spree_credit_memos_on_txn_class_id", using: :btree
  add_index "spree_credit_memos", ["txn_date"], name: "index_spree_credit_memos_on_txn_date", using: :btree
  add_index "spree_credit_memos", ["vendor_id"], name: "index_spree_credit_memos_on_vendor_id", using: :btree

  create_table "spree_credit_transactions", force: :cascade do |t|
    t.boolean  "use_credit",                               default: false
    t.integer  "account_id",                                               null: false
    t.decimal  "amount",          precision: 15, scale: 5, default: 0,     null: false
    t.datetime "created_at",                                               null: false
    t.datetime "updated_at",                                               null: false
    t.integer  "originator_id"
    t.string   "originator_type"
  end

  add_index "spree_credit_transactions", ["account_id"], name: "index_spree_credit_transactions_on_account_id", using: :btree
  add_index "spree_credit_transactions", ["originator_type", "originator_id"], name: "index_credit_orig_pol", using: :btree

  create_table "spree_customer_imports", force: :cascade do |t|
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.integer  "file_file_size"
    t.datetime "file_updated_at"
    t.string   "encoding"
    t.string   "delimer"
    t.boolean  "replace"
    t.integer  "status"
    t.json     "verify_result"
    t.json     "import_result"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.boolean  "proceed"
    t.boolean  "proceed_verified"
    t.text     "exception_message"
    t.integer  "vendor_id"
  end

  create_table "spree_customer_returns", force: :cascade do |t|
    t.string   "number"
    t.integer  "stock_location_id"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "spree_customer_returns", ["stock_location_id"], name: "index_spree_customer_returns_on_stock_location_id", using: :btree

  create_table "spree_customer_types", force: :cascade do |t|
    t.string  "name",      null: false
    t.integer "vendor_id"
  end

  create_table "spree_customer_viewable_attributes", force: :cascade do |t|
    t.integer "vendor_id",          null: false
    t.jsonb   "product"
    t.jsonb   "variant"
    t.jsonb   "line_item"
    t.jsonb   "order"
    t.jsonb   "invoice"
    t.jsonb   "account"
    t.jsonb   "payment"
    t.jsonb   "standing_line_item"
    t.jsonb   "standing_order"
    t.json    "theme_colors"
    t.string  "theme_name"
    t.text    "theme_css"
    t.string  "banner_color"
    t.text    "about_us"
    t.integer "banner_image_id"
    t.text    "announcement"
    t.jsonb   "pages"
  end

  add_index "spree_customer_viewable_attributes", ["vendor_id"], name: "index_spree_customer_viewable_attributes_on_vendor_id", using: :btree

  create_table "spree_customers_vendors", force: :cascade do |t|
    t.integer  "customer_id"
    t.integer  "vendor_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "spree_customers_vendors", ["customer_id"], name: "index_spree_customers_vendors_on_customer_id", using: :btree
  add_index "spree_customers_vendors", ["vendor_id"], name: "index_spree_customers_vendors_on_vendor_id", using: :btree

  create_table "spree_datatable_settings", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "path_name",  null: false
    t.jsonb    "state",      null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "spree_datatable_settings", ["path_name"], name: "index_spree_datatable_settings_on_path_name", using: :btree
  add_index "spree_datatable_settings", ["user_id"], name: "index_spree_datatable_settings_on_user_id", using: :btree

  create_table "spree_email_templates", force: :cascade do |t|
    t.string  "subject"
    t.string  "from"
    t.string  "bcc"
    t.string  "cc"
    t.string  "slug",      null: false
    t.string  "file_path", null: false
    t.text    "body",      null: false
    t.text    "template",  null: false
    t.integer "vendor_id"
  end

  add_index "spree_email_templates", ["slug"], name: "index_spree_email_templates_on_slug", using: :btree
  add_index "spree_email_templates", ["vendor_id"], name: "index_spree_email_templates_on_vendor_id", using: :btree

  create_table "spree_form_fields", force: :cascade do |t|
    t.integer "form_id",                     null: false
    t.string  "field_type",                  null: false
    t.boolean "required",    default: false, null: false
    t.integer "num_columns", default: 1,     null: false
    t.string  "label"
    t.text    "value"
    t.integer "position"
    t.string  "css_class"
  end

  add_index "spree_form_fields", ["form_id"], name: "index_spree_form_fields_on_form_id", using: :btree

  create_table "spree_forms", force: :cascade do |t|
    t.string   "form_type",                      null: false
    t.integer  "vendor_id",                      null: false
    t.string   "name",                           null: false
    t.boolean  "active",          default: true, null: false
    t.integer  "num_columns",     default: 1,    null: false
    t.string   "title"
    t.text     "instructions"
    t.string   "submit_text"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "link_to_text"
    t.text     "success_message"
  end

  add_index "spree_forms", ["active"], name: "index_spree_forms_on_active", using: :btree
  add_index "spree_forms", ["name"], name: "index_spree_forms_on_name", using: :btree
  add_index "spree_forms", ["vendor_id"], name: "index_spree_forms_on_vendor_id", using: :btree

  create_table "spree_gateways", force: :cascade do |t|
    t.string   "type"
    t.string   "name"
    t.text     "description"
    t.boolean  "active",      default: true
    t.string   "environment", default: "development"
    t.string   "server",      default: "test"
    t.boolean  "test_mode",   default: true
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
    t.text     "preferences"
  end

  add_index "spree_gateways", ["active"], name: "index_spree_gateways_on_active", using: :btree
  add_index "spree_gateways", ["test_mode"], name: "index_spree_gateways_on_test_mode", using: :btree

  create_table "spree_integration_actions", force: :cascade do |t|
    t.integer  "integrationable_id"
    t.string   "integrationable_type"
    t.integer  "integration_item_id"
    t.integer  "status"
    t.text     "execution_log"
    t.integer  "execution_count"
    t.datetime "enqueued_at"
    t.datetime "processed_at"
    t.jsonb    "prev_step"
    t.jsonb    "step"
    t.string   "sync_id"
    t.string   "sync_type"
    t.string   "sync_fully_qualified_name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text     "execution_backtrace"
    t.datetime "last_response_time"
    t.string   "sidekiq_jid"
  end

  add_index "spree_integration_actions", ["enqueued_at"], name: "index_spree_integration_actions_on_enqueued_at", using: :btree
  add_index "spree_integration_actions", ["integration_item_id"], name: "index_spree_integration_actions_on_integration_item_id", using: :btree
  add_index "spree_integration_actions", ["integrationable_id", "integrationable_type", "status"], name: "spree_integration_actions_on_integrationable_status", using: :btree
  add_index "spree_integration_actions", ["integrationable_id", "integrationable_type"], name: "spree_integration_actions_on_integrationable", using: :btree
  add_index "spree_integration_actions", ["integrationable_id"], name: "index_spree_integration_actions_on_integrationable_id", using: :btree
  add_index "spree_integration_actions", ["integrationable_type"], name: "index_spree_integration_actions_on_integrationable_type", using: :btree
  add_index "spree_integration_actions", ["processed_at"], name: "index_spree_integration_actions_on_processed_at", using: :btree
  add_index "spree_integration_actions", ["status"], name: "index_spree_integration_actions_on_status", using: :btree
  add_index "spree_integration_actions", ["sync_fully_qualified_name"], name: "index_spree_integration_actions_on_sync_fully_qualified_name", using: :btree
  add_index "spree_integration_actions", ["sync_id"], name: "index_spree_integration_actions_on_sync_id", using: :btree
  add_index "spree_integration_actions", ["sync_type"], name: "index_spree_integration_actions_on_sync_type", using: :btree

  create_table "spree_integration_items", force: :cascade do |t|
    t.string   "integration_key"
    t.json     "settings"
    t.integer  "status"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
    t.integer  "vendor_id"
    t.text     "last_action"
    t.text     "last_error"
    t.boolean  "order_sync"
    t.boolean  "account_sync"
    t.boolean  "variant_sync"
    t.string   "integration_type"
    t.boolean  "should_timeout",   default: false
  end

  add_index "spree_integration_items", ["account_sync"], name: "index_spree_integration_items_on_account_sync", using: :btree
  add_index "spree_integration_items", ["integration_key"], name: "index_spree_integration_items_on_integration_key", using: :btree
  add_index "spree_integration_items", ["order_sync"], name: "index_spree_integration_items_on_order_sync", using: :btree
  add_index "spree_integration_items", ["variant_sync"], name: "index_spree_integration_items_on_variant_sync", using: :btree

  create_table "spree_integration_steps", force: :cascade do |t|
    t.integer  "integration_action_id"
    t.integer  "parent_id"
    t.integer  "status",                  default: 0,       null: false
    t.string   "integrationable_type"
    t.jsonb    "details",                 default: {},      null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "is_current",              default: false,   null: false
    t.string   "sync_id"
    t.string   "sync_type"
    t.integer  "integration_syncable_id"
    t.string   "master",                  default: "sweet"
    t.integer  "position",                default: 1,       null: false
  end

  add_index "spree_integration_steps", ["integration_action_id"], name: "index_spree_integration_steps_on_integration_action_id", using: :btree
  add_index "spree_integration_steps", ["integration_syncable_id"], name: "index_spree_integration_steps_on_integration_syncable_id", using: :btree
  add_index "spree_integration_steps", ["is_current"], name: "index_spree_integration_steps_on_is_current", using: :btree
  add_index "spree_integration_steps", ["parent_id"], name: "index_spree_integration_steps_on_parent_id", using: :btree
  add_index "spree_integration_steps", ["position"], name: "index_spree_integration_steps_on_position", using: :btree
  add_index "spree_integration_steps", ["sync_id"], name: "index_spree_integration_steps_on_sync_id", using: :btree
  add_index "spree_integration_steps", ["sync_type"], name: "index_spree_integration_steps_on_sync_type", using: :btree

  create_table "spree_integration_sync_matches", force: :cascade do |t|
    t.integer  "integration_syncable_id"
    t.string   "integration_syncable_type"
    t.integer  "integration_item_id"
    t.string   "sync_id"
    t.string   "sync_type"
    t.string   "sync_alt_id"
    t.datetime "synced_at"
    t.boolean  "no_sync",                   default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "sync_object_created_at"
    t.string   "sync_object_updated_at"
  end

  add_index "spree_integration_sync_matches", ["integration_item_id", "integration_syncable_id", "integration_syncable_type"], name: "index_spreeintegrationsyncmatches_on_intemandsyncable", using: :btree
  add_index "spree_integration_sync_matches", ["integration_item_id"], name: "index_spree_integration_sync_matches_on_integration_item_id", using: :btree
  add_index "spree_integration_sync_matches", ["integration_syncable_id", "integration_syncable_type"], name: "index_spreeintegrationsyncmatches_on_integrationsyncable", using: :btree
  add_index "spree_integration_sync_matches", ["integration_syncable_id"], name: "index_spree_integration_sync_matches_on_integration_syncable_id", using: :btree
  add_index "spree_integration_sync_matches", ["integration_syncable_type"], name: "index_spreeintegrationsyncmatches_on_integrationsyncabletype", using: :btree
  add_index "spree_integration_sync_matches", ["sync_id", "sync_type"], name: "index_spree_integration_sync_matches_on_sync_id_and_sync_type", using: :btree
  add_index "spree_integration_sync_matches", ["sync_id"], name: "index_spree_integration_sync_matches_on_sync_id", using: :btree
  add_index "spree_integration_sync_matches", ["sync_type"], name: "index_spree_integration_sync_matches_on_sync_type", using: :btree

  create_table "spree_inventory_units", force: :cascade do |t|
    t.string   "state"
    t.integer  "variant_id"
    t.integer  "order_id"
    t.integer  "shipment_id"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.boolean  "pending",                               default: true
    t.integer  "line_item_id"
    t.integer  "lot_id"
    t.decimal  "quantity",     precision: 15, scale: 5
  end

  add_index "spree_inventory_units", ["line_item_id"], name: "index_spree_inventory_units_on_line_item_id", using: :btree
  add_index "spree_inventory_units", ["lot_id"], name: "index_spree_inventory_units_on_lot_id", using: :btree
  add_index "spree_inventory_units", ["order_id"], name: "index_inventory_units_on_order_id", using: :btree
  add_index "spree_inventory_units", ["shipment_id"], name: "index_inventory_units_on_shipment_id", using: :btree
  add_index "spree_inventory_units", ["variant_id"], name: "index_inventory_units_on_variant_id", using: :btree

  create_table "spree_invoices", force: :cascade do |t|
    t.datetime "start_date"
    t.datetime "end_date"
    t.boolean  "multi_order"
    t.string   "number"
    t.string   "state"
    t.decimal  "item_total",           default: 0, null: false
    t.decimal  "total",                default: 0, null: false
    t.decimal  "adjustment_total",     default: 0, null: false
    t.integer  "bill_address_id"
    t.integer  "ship_address_id"
    t.decimal  "payment_total"
    t.string   "payment_state"
    t.datetime "payment_due_date"
    t.string   "currency"
    t.decimal  "shipment_total",       default: 0, null: false
    t.decimal  "additional_tax_total", default: 0, null: false
    t.decimal  "promo_total",          default: 0, null: false
    t.decimal  "included_tax_total",   default: 0, null: false
    t.integer  "item_count"
    t.integer  "account_id"
    t.boolean  "confirm_sent"
    t.boolean  "confirm_returned"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "vendor_id"
    t.integer  "customer_id"
    t.datetime "due_date"
    t.datetime "reminder_sent_at"
    t.datetime "past_due_sent_at"
    t.datetime "invoice_date"
  end

  add_index "spree_invoices", ["account_id"], name: "index_spree_invoices_on_account_id", using: :btree
  add_index "spree_invoices", ["customer_id"], name: "index_spree_invoices_on_customer_id", using: :btree
  add_index "spree_invoices", ["due_date"], name: "index_spree_invoices_on_due_date", using: :btree
  add_index "spree_invoices", ["invoice_date"], name: "index_spree_invoices_on_invoice_date", using: :btree
  add_index "spree_invoices", ["multi_order"], name: "index_spree_invoices_on_multi_order", using: :btree
  add_index "spree_invoices", ["number"], name: "index_spree_invoices_on_number", using: :btree
  add_index "spree_invoices", ["past_due_sent_at"], name: "index_spree_invoices_on_past_due_sent_at", using: :btree
  add_index "spree_invoices", ["payment_state"], name: "index_spree_invoices_on_payment_state", using: :btree
  add_index "spree_invoices", ["reminder_sent_at"], name: "index_spree_invoices_on_reminder_sent_at", using: :btree
  add_index "spree_invoices", ["state"], name: "index_spree_invoices_on_state", using: :btree
  add_index "spree_invoices", ["total"], name: "index_spree_invoices_on_total", using: :btree

  create_table "spree_line_item_lots", force: :cascade do |t|
    t.integer "lot_id",                                               null: false
    t.integer "line_item_id",                                         null: false
    t.decimal "count",           precision: 15, scale: 5, default: 0, null: false
    t.integer "variant_part_id"
  end

  add_index "spree_line_item_lots", ["line_item_id"], name: "index_spree_line_item_lots_on_line_item_id", using: :btree
  add_index "spree_line_item_lots", ["lot_id"], name: "index_spree_line_item_lots_on_lot_id", using: :btree

  create_table "spree_line_items", force: :cascade do |t|
    t.integer  "variant_id"
    t.integer  "order_id"
    t.decimal  "quantity",             precision: 15, scale: 5,                 null: false
    t.decimal  "price",                precision: 10, scale: 2,                 null: false
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
    t.string   "currency"
    t.decimal  "cost_price",           precision: 10, scale: 2
    t.integer  "tax_category_id"
    t.decimal  "adjustment_total",     precision: 10, scale: 2, default: 0
    t.decimal  "additional_tax_total", precision: 10, scale: 2, default: 0
    t.decimal  "promo_total",          precision: 10, scale: 2, default: 0
    t.decimal  "included_tax_total",   precision: 10, scale: 2, default: 0,     null: false
    t.decimal  "pre_tax_amount",       precision: 12, scale: 4, default: 0,     null: false
    t.decimal  "shipped_qty",          precision: 15, scale: 5
    t.decimal  "ordered_qty",          precision: 15, scale: 5
    t.decimal  "shipped_total"
    t.decimal  "ordered_total"
    t.boolean  "confirm_received",                              default: false
    t.decimal  "price_discount",                                default: 0
    t.string   "item_name"
    t.string   "lot_number"
    t.string   "pack_size",                                     default: "",    null: false
    t.integer  "txn_class_id"
    t.integer  "position"
    t.string   "text_option"
  end

  add_index "spree_line_items", ["item_name"], name: "index_spree_line_items_on_item_name", using: :btree
  add_index "spree_line_items", ["lot_number"], name: "index_spree_line_items_on_lot_number", using: :btree
  add_index "spree_line_items", ["order_id"], name: "index_spree_line_items_on_order_id", using: :btree
  add_index "spree_line_items", ["pack_size"], name: "index_spree_line_items_on_pack_size", using: :btree
  add_index "spree_line_items", ["position"], name: "index_spree_line_items_on_position", using: :btree
  add_index "spree_line_items", ["tax_category_id"], name: "index_spree_line_items_on_tax_category_id", using: :btree
  add_index "spree_line_items", ["txn_class_id"], name: "index_spree_line_items_on_txn_class_id", using: :btree
  add_index "spree_line_items", ["variant_id"], name: "index_spree_line_items_on_variant_id", using: :btree

  create_table "spree_log_entries", force: :cascade do |t|
    t.integer  "source_id"
    t.string   "source_type"
    t.text     "details"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
  end

  add_index "spree_log_entries", ["source_id", "source_type"], name: "index_spree_log_entries_on_source_id_and_source_type", using: :btree

  create_table "spree_lots", force: :cascade do |t|
    t.string   "number",                                            null: false
    t.decimal  "qty_on_hand",  precision: 15, scale: 5, default: 0, null: false
    t.decimal  "qty_sold",     precision: 15, scale: 5, default: 0, null: false
    t.decimal  "qty_waste",    precision: 15, scale: 5, default: 0, null: false
    t.datetime "available_at"
    t.datetime "expires_at"
    t.datetime "sell_by"
    t.datetime "created_at",                                        null: false
    t.datetime "updated_at",                                        null: false
    t.integer  "variant_id",                                        null: false
    t.integer  "vendor_id",                                         null: false
    t.datetime "archived_at"
  end

  add_index "spree_lots", ["archived_at"], name: "index_spree_lots_on_archived_at", using: :btree
  add_index "spree_lots", ["available_at"], name: "index_spree_lots_on_available_at", using: :btree
  add_index "spree_lots", ["created_at"], name: "index_spree_lots_on_created_at", using: :btree
  add_index "spree_lots", ["expires_at"], name: "index_spree_lots_on_expires_at", using: :btree
  add_index "spree_lots", ["number"], name: "index_spree_lots_on_number", using: :btree
  add_index "spree_lots", ["sell_by"], name: "index_spree_lots_on_sell_by", using: :btree
  add_index "spree_lots", ["variant_id"], name: "index_spree_lots_on_variant_id", using: :btree
  add_index "spree_lots", ["vendor_id"], name: "index_spree_lots_on_vendor_id", using: :btree

  create_table "spree_master_credit_cards", force: :cascade do |t|
    t.integer  "company_id"
    t.integer  "credit_cards_id"
    t.string   "month"
    t.string   "year"
    t.string   "cc_type"
    t.string   "last_digits"
    t.integer  "address_id"
    t.string   "verification_value"
    t.string   "gateway_customer_profile_id"
    t.string   "gateway_payment_profile_id"
    t.string   "name"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  create_table "spree_notes", force: :cascade do |t|
    t.text     "body"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "account_id", null: false
  end

  add_index "spree_notes", ["account_id"], name: "index_spree_notes_on_account_id", using: :btree

  create_table "spree_option_types", force: :cascade do |t|
    t.string   "name",         limit: 100
    t.string   "presentation", limit: 100
    t.integer  "position",                 default: 0, null: false
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.integer  "vendor_id"
  end

  add_index "spree_option_types", ["position"], name: "index_spree_option_types_on_position", using: :btree
  add_index "spree_option_types", ["vendor_id"], name: "index_spree_option_types_on_vendor_id", using: :btree

  create_table "spree_option_types_prototypes", id: false, force: :cascade do |t|
    t.integer "prototype_id"
    t.integer "option_type_id"
  end

  add_index "spree_option_types_prototypes", ["option_type_id"], name: "index_spree_option_types_prototypes_on_option_type_id", using: :btree
  add_index "spree_option_types_prototypes", ["prototype_id", "option_type_id"], name: "index_spree_option_types_prototypes_on_prototype_option_type", using: :btree
  add_index "spree_option_types_prototypes", ["prototype_id"], name: "index_spree_option_types_prototypes_on_prototype_id", using: :btree

  create_table "spree_option_values", force: :cascade do |t|
    t.integer  "position"
    t.string   "name"
    t.string   "presentation"
    t.integer  "option_type_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.integer  "vendor_id"
  end

  add_index "spree_option_values", ["option_type_id"], name: "index_spree_option_values_on_option_type_id", using: :btree
  add_index "spree_option_values", ["position"], name: "index_spree_option_values_on_position", using: :btree

  create_table "spree_option_values_variants", force: :cascade do |t|
    t.integer "variant_id"
    t.integer "option_value_id"
  end

  add_index "spree_option_values_variants", ["variant_id", "option_value_id"], name: "index_option_values_variants_on_variant_id_and_option_value_id", using: :btree
  add_index "spree_option_values_variants", ["variant_id"], name: "index_spree_option_values_variants_on_variant_id", using: :btree

  create_table "spree_order_rules", force: :cascade do |t|
    t.integer  "vendor_id"
    t.boolean  "active",      default: true, null: false
    t.integer  "rule_type",                  null: false
    t.integer  "value"
    t.datetime "created_at",                 null: false
    t.datetime "updated_at",                 null: false
    t.string   "taxon_ids"
    t.string   "description"
  end

  add_index "spree_order_rules", ["vendor_id"], name: "index_spree_order_rules_on_vendor_id", using: :btree

  create_table "spree_ordered_parts", force: :cascade do |t|
    t.integer  "part_variant_id",                          null: false
    t.integer  "line_item_id",                             null: false
    t.decimal  "quantity",        precision: 15, scale: 5, null: false
    t.decimal  "part_qty",        precision: 15, scale: 5, null: false
    t.datetime "created_at",                               null: false
    t.datetime "updated_at",                               null: false
  end

  add_index "spree_ordered_parts", ["line_item_id"], name: "index_spree_ordered_parts_on_line_item_id", using: :btree

  create_table "spree_orders", force: :cascade do |t|
    t.string   "number",                 limit: 32
    t.decimal  "item_total",                        precision: 10, scale: 2, default: 0,       null: false
    t.decimal  "total",                             precision: 10, scale: 2, default: 0,       null: false
    t.string   "state"
    t.decimal  "adjustment_total",                  precision: 10, scale: 2, default: 0,       null: false
    t.integer  "user_id"
    t.datetime "completed_at"
    t.integer  "bill_address_id"
    t.integer  "ship_address_id"
    t.decimal  "payment_total",                     precision: 10, scale: 2, default: 0
    t.integer  "shipping_method_id"
    t.string   "shipment_state"
    t.string   "payment_state"
    t.string   "email"
    t.text     "special_instructions"
    t.datetime "created_at",                                                                   null: false
    t.datetime "updated_at",                                                                   null: false
    t.string   "currency"
    t.string   "last_ip_address"
    t.integer  "created_by_id"
    t.decimal  "shipment_total",                    precision: 10, scale: 2, default: 0,       null: false
    t.decimal  "additional_tax_total",              precision: 10, scale: 2, default: 0
    t.decimal  "promo_total",                       precision: 10, scale: 2, default: 0
    t.string   "channel",                                                    default: "sweet"
    t.decimal  "included_tax_total",                precision: 10, scale: 2, default: 0,       null: false
    t.decimal  "item_count",                        precision: 15, scale: 5, default: 0
    t.integer  "approver_id"
    t.datetime "approved_at"
    t.boolean  "confirmation_delivered",                                     default: false
    t.boolean  "considered_risky",                                           default: false
    t.string   "guest_token"
    t.datetime "canceled_at"
    t.integer  "canceler_id"
    t.integer  "store_id"
    t.integer  "state_lock_version",                                         default: 0,       null: false
    t.datetime "delivery_date"
    t.boolean  "is_delivery?",                                               default: true
    t.integer  "account_id"
    t.boolean  "approved",                                                   default: false
    t.string   "po_number"
    t.integer  "invoice_id"
    t.integer  "vendor_id"
    t.integer  "customer_id"
    t.boolean  "override_shipment_cost",                                     default: false
    t.jsonb    "custom_attrs"
    t.datetime "invoiced_at"
    t.datetime "invoice_sent_at"
    t.datetime "invoice_date"
    t.datetime "due_date"
    t.string   "order_type",                                                 default: "sales"
    t.integer  "txn_class_id"
    t.integer  "po_stock_location_id"
    t.boolean  "recalculate_shipping",                                       default: false
  end

  add_index "spree_orders", ["account_id"], name: "index_spree_orders_on_account_id", using: :btree
  add_index "spree_orders", ["approver_id"], name: "index_spree_orders_on_approver_id", using: :btree
  add_index "spree_orders", ["bill_address_id"], name: "index_spree_orders_on_bill_address_id", using: :btree
  add_index "spree_orders", ["completed_at"], name: "index_spree_orders_on_completed_at", using: :btree
  add_index "spree_orders", ["confirmation_delivered"], name: "index_spree_orders_on_confirmation_delivered", using: :btree
  add_index "spree_orders", ["considered_risky"], name: "index_spree_orders_on_considered_risky", using: :btree
  add_index "spree_orders", ["created_by_id"], name: "index_spree_orders_on_created_by_id", using: :btree
  add_index "spree_orders", ["due_date"], name: "index_spree_orders_on_due_date", using: :btree
  add_index "spree_orders", ["guest_token"], name: "index_spree_orders_on_guest_token", using: :btree
  add_index "spree_orders", ["invoice_date"], name: "index_spree_orders_on_invoice_date", using: :btree
  add_index "spree_orders", ["invoice_id"], name: "index_spree_orders_on_invoice_id", using: :btree
  add_index "spree_orders", ["invoice_sent_at"], name: "index_spree_orders_on_invoice_sent_at", using: :btree
  add_index "spree_orders", ["invoiced_at"], name: "index_spree_orders_on_invoiced_at", using: :btree
  add_index "spree_orders", ["number"], name: "index_spree_orders_on_number", using: :btree
  add_index "spree_orders", ["po_number"], name: "index_spree_orders_on_po_number", using: :btree
  add_index "spree_orders", ["ship_address_id"], name: "index_spree_orders_on_ship_address_id", using: :btree
  add_index "spree_orders", ["shipping_method_id"], name: "index_spree_orders_on_shipping_method_id", using: :btree
  add_index "spree_orders", ["txn_class_id"], name: "index_spree_orders_on_txn_class_id", using: :btree
  add_index "spree_orders", ["user_id", "created_by_id"], name: "index_spree_orders_on_user_id_and_created_by_id", using: :btree
  add_index "spree_orders", ["user_id"], name: "index_spree_orders_on_user_id", using: :btree

  create_table "spree_orders_promotions", id: false, force: :cascade do |t|
    t.integer "order_id"
    t.integer "promotion_id"
  end

  add_index "spree_orders_promotions", ["order_id", "promotion_id"], name: "index_spree_orders_promotions_on_order_id_and_promotion_id", using: :btree
  add_index "spree_orders_promotions", ["order_id"], name: "index_spree_orders_promotions_on_order_id", using: :btree
  add_index "spree_orders_promotions", ["promotion_id"], name: "index_spree_orders_promotions_on_promotion_id", using: :btree

  create_table "spree_pages", force: :cascade do |t|
    t.string   "title"
    t.text     "body"
    t.string   "slug"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.boolean  "show_in_header",           default: false, null: false
    t.boolean  "show_in_footer",           default: false, null: false
    t.string   "foreign_link"
    t.integer  "position",                 default: 1,     null: false
    t.boolean  "visible",                  default: true
    t.string   "meta_keywords"
    t.string   "meta_description"
    t.string   "layout"
    t.boolean  "show_in_sidebar",          default: false, null: false
    t.string   "meta_title"
    t.boolean  "render_layout_as_partial", default: false
    t.integer  "company_id"
  end

  add_index "spree_pages", ["company_id"], name: "index_spree_pages_on_company_id", using: :btree
  add_index "spree_pages", ["slug"], name: "index_spree_pages_on_slug", using: :btree

  create_table "spree_pages_stores", id: false, force: :cascade do |t|
    t.integer  "store_id"
    t.integer  "page_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "spree_pages_stores", ["page_id"], name: "index_spree_pages_stores_on_page_id", using: :btree
  add_index "spree_pages_stores", ["store_id"], name: "index_spree_pages_stores_on_store_id", using: :btree

  create_table "spree_part_line_items", force: :cascade do |t|
    t.integer "line_item_id",                                      null: false
    t.integer "variant_id",                                        null: false
    t.decimal "quantity",     precision: 15, scale: 5, default: 1
  end

  create_table "spree_part_lots", force: :cascade do |t|
    t.integer "assembly_lot_id",             null: false
    t.integer "part_lot_id",                 null: false
    t.integer "parent_id"
    t.integer "lft",                         null: false
    t.integer "rgt",                         null: false
    t.integer "depth",           default: 0, null: false
    t.integer "children_count",  default: 0, null: false
  end

  add_index "spree_part_lots", ["assembly_lot_id"], name: "index_spree_part_lots_on_assembly_lot_id", using: :btree
  add_index "spree_part_lots", ["lft"], name: "index_spree_part_lots_on_lft", using: :btree
  add_index "spree_part_lots", ["parent_id"], name: "index_spree_part_lots_on_parent_id", using: :btree
  add_index "spree_part_lots", ["part_lot_id"], name: "index_spree_part_lots_on_part_lot_id", using: :btree
  add_index "spree_part_lots", ["rgt"], name: "index_spree_part_lots_on_rgt", using: :btree

  create_table "spree_payment_capture_events", force: :cascade do |t|
    t.decimal  "amount",             precision: 10, scale: 2, default: 0
    t.integer  "payment_id"
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
    t.integer  "account_payment_id"
  end

  add_index "spree_payment_capture_events", ["payment_id"], name: "index_spree_payment_capture_events_on_payment_id", using: :btree

  create_table "spree_payment_methods", force: :cascade do |t|
    t.string   "type"
    t.string   "name"
    t.text     "description"
    t.boolean  "active",       default: true
    t.datetime "deleted_at"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
    t.string   "display_on"
    t.boolean  "auto_capture"
    t.text     "preferences"
    t.integer  "vendor_id"
    t.boolean  "mark_paid",    default: false, null: false
  end

  add_index "spree_payment_methods", ["id", "type"], name: "index_spree_payment_methods_on_id_and_type", using: :btree
  add_index "spree_payment_methods", ["mark_paid"], name: "index_spree_payment_methods_on_mark_paid", using: :btree
  add_index "spree_payment_methods", ["vendor_id"], name: "index_spree_payment_methods_on_vendor_id", using: :btree

  create_table "spree_payment_terms", force: :cascade do |t|
    t.string  "name",                              null: false
    t.text    "description"
    t.integer "num_days",          default: 0
    t.boolean "pay_before_submit", default: false, null: false
  end

  add_index "spree_payment_terms", ["name"], name: "index_spree_payment_terms_on_name", using: :btree
  add_index "spree_payment_terms", ["num_days"], name: "index_spree_payment_terms_on_num_days", using: :btree
  add_index "spree_payment_terms", ["pay_before_submit"], name: "index_spree_payment_terms_on_pay_before_submit", using: :btree

  create_table "spree_payments", force: :cascade do |t|
    t.decimal  "amount",               precision: 10, scale: 2, default: 0,       null: false
    t.integer  "order_id"
    t.integer  "source_id"
    t.string   "source_type"
    t.integer  "payment_method_id"
    t.string   "state"
    t.string   "response_code"
    t.string   "avs_response"
    t.datetime "created_at",                                                      null: false
    t.datetime "updated_at",                                                      null: false
    t.string   "number"
    t.string   "cvv_response_code"
    t.string   "cvv_response_message"
    t.text     "memo"
    t.string   "txn_id"
    t.integer  "account_payment_id"
    t.string   "channel",                                       default: "sweet", null: false
  end

  add_index "spree_payments", ["account_payment_id"], name: "index_spree_payments_on_account_payment_id", using: :btree
  add_index "spree_payments", ["channel"], name: "index_spree_payments_on_channel", using: :btree
  add_index "spree_payments", ["order_id"], name: "index_spree_payments_on_order_id", using: :btree
  add_index "spree_payments", ["payment_method_id"], name: "index_spree_payments_on_payment_method_id", using: :btree
  add_index "spree_payments", ["source_id", "source_type"], name: "index_spree_payments_on_source_id_and_source_type", using: :btree

  create_table "spree_permission_groups", force: :cascade do |t|
    t.string  "name",                        null: false
    t.integer "company_id"
    t.jsonb   "permissions"
    t.boolean "is_default",  default: false
  end

  add_index "spree_permission_groups", ["company_id"], name: "index_spree_permission_groups_on_company_id", using: :btree
  add_index "spree_permission_groups", ["is_default"], name: "index_spree_permission_groups_on_is_default", using: :btree

  create_table "spree_preferences", force: :cascade do |t|
    t.text     "value"
    t.string   "key"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "spree_preferences", ["key"], name: "index_spree_preferences_on_key", unique: true, using: :btree

  create_table "spree_price_list_accounts", force: :cascade do |t|
    t.integer "price_list_id"
    t.integer "account_id"
  end

  add_index "spree_price_list_accounts", ["account_id"], name: "index_spree_price_list_accounts_on_account_id", using: :btree
  add_index "spree_price_list_accounts", ["price_list_id"], name: "index_spree_price_list_accounts_on_price_list_id", using: :btree

  create_table "spree_price_list_variants", force: :cascade do |t|
    t.integer  "variant_id"
    t.integer  "price_list_id"
    t.decimal  "price",         precision: 10, scale: 2, default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "spree_price_list_variants", ["price"], name: "index_spree_price_list_variants_on_price", using: :btree
  add_index "spree_price_list_variants", ["price_list_id"], name: "index_spree_price_list_variants_on_price_list_id", using: :btree
  add_index "spree_price_list_variants", ["variant_id"], name: "index_spree_price_list_variants_on_variant_id", using: :btree

  create_table "spree_price_lists", force: :cascade do |t|
    t.string   "name"
    t.integer  "vendor_id"
    t.integer  "customer_type_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string   "select_customers_by", default: "individual", null: false
    t.string   "select_variants_by",  default: "individual", null: false
    t.string   "adjustment_method",   default: "custom"
    t.integer  "adjustment_operator", default: -1
    t.decimal  "adjustment_value"
    t.boolean  "active",              default: true,         null: false
  end

  add_index "spree_price_lists", ["active"], name: "index_spree_price_lists_on_active", using: :btree
  add_index "spree_price_lists", ["customer_type_id"], name: "index_spree_price_lists_on_customer_type_id", using: :btree
  add_index "spree_price_lists", ["name"], name: "index_spree_price_lists_on_name", using: :btree
  add_index "spree_price_lists", ["select_customers_by"], name: "index_spree_price_lists_on_select_customers_by", using: :btree
  add_index "spree_price_lists", ["vendor_id"], name: "index_spree_price_lists_on_vendor_id", using: :btree

  create_table "spree_prices", force: :cascade do |t|
    t.integer  "variant_id",                          null: false
    t.decimal  "amount",     precision: 10, scale: 2
    t.string   "currency"
    t.datetime "deleted_at"
  end

  add_index "spree_prices", ["deleted_at", "variant_id"], name: "index_spree_prices_on_deleted_at_and_variant_id", using: :btree
  add_index "spree_prices", ["deleted_at"], name: "index_spree_prices_on_deleted_at", using: :btree
  add_index "spree_prices", ["variant_id", "currency"], name: "index_spree_prices_on_variant_id_and_currency", using: :btree

  create_table "spree_product_imports", force: :cascade do |t|
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.integer  "file_file_size"
    t.datetime "file_updated_at"
    t.string   "encoding"
    t.string   "delimer"
    t.boolean  "replace"
    t.integer  "status"
    t.json     "verify_result"
    t.json     "import_result"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
    t.boolean  "proceed"
    t.boolean  "proceed_verified"
    t.text     "exception_message"
    t.integer  "vendor_id"
  end

  create_table "spree_product_integration_items", force: :cascade do |t|
    t.integer "product_id", null: false
    t.integer "item_id",    null: false
  end

  add_index "spree_product_integration_items", ["item_id"], name: "index_spree_product_integration_items_on_item_id", using: :btree
  add_index "spree_product_integration_items", ["product_id"], name: "index_spree_product_integration_items_on_product_id", using: :btree

  create_table "spree_product_option_types", force: :cascade do |t|
    t.integer  "position"
    t.integer  "product_id"
    t.integer  "option_type_id"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "spree_product_option_types", ["option_type_id"], name: "index_spree_product_option_types_on_option_type_id", using: :btree
  add_index "spree_product_option_types", ["position"], name: "index_spree_product_option_types_on_position", using: :btree
  add_index "spree_product_option_types", ["product_id"], name: "index_spree_product_option_types_on_product_id", using: :btree

  create_table "spree_product_packages", force: :cascade do |t|
    t.integer  "product_id",             null: false
    t.integer  "length",     default: 0, null: false
    t.integer  "width",      default: 0, null: false
    t.integer  "height",     default: 0, null: false
    t.integer  "weight",     default: 0, null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "spree_product_properties", force: :cascade do |t|
    t.string   "value"
    t.integer  "product_id"
    t.integer  "property_id"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.integer  "position",    default: 0
  end

  add_index "spree_product_properties", ["position"], name: "index_spree_product_properties_on_position", using: :btree
  add_index "spree_product_properties", ["product_id"], name: "index_product_properties_on_product_id", using: :btree
  add_index "spree_product_properties", ["property_id"], name: "index_spree_product_properties_on_property_id", using: :btree

  create_table "spree_products", force: :cascade do |t|
    t.string   "name",                 default: "",    null: false
    t.text     "description"
    t.datetime "available_on"
    t.datetime "deleted_at"
    t.string   "slug"
    t.text     "meta_description"
    t.string   "meta_keywords"
    t.integer  "tax_category_id"
    t.integer  "shipping_category_id"
    t.datetime "created_at",                           null: false
    t.datetime "updated_at",                           null: false
    t.boolean  "promotionable",        default: true
    t.string   "meta_title"
    t.string   "tax_cloud_tic"
    t.integer  "vendor_id"
    t.datetime "discontinued_on"
    t.string   "product_type"
    t.integer  "income_account_id"
    t.integer  "expense_account_id"
    t.integer  "cogs_account_id"
    t.integer  "asset_account_id"
    t.boolean  "for_sale",             default: true,  null: false
    t.boolean  "for_purchase",         default: false, null: false
    t.boolean  "can_be_part",          default: false, null: false
    t.boolean  "individual_sale",      default: true,  null: false
    t.string   "display_name",         default: "",    null: false
    t.string   "default_display_name", default: "",    null: false
  end

  add_index "spree_products", ["available_on"], name: "index_spree_products_on_available_on", using: :btree
  add_index "spree_products", ["deleted_at"], name: "index_spree_products_on_deleted_at", using: :btree
  add_index "spree_products", ["discontinued_on"], name: "index_spree_products_on_discontinued_on", using: :btree
  add_index "spree_products", ["for_purchase"], name: "index_spree_products_on_for_purchase", using: :btree
  add_index "spree_products", ["for_sale"], name: "index_spree_products_on_for_sale", using: :btree
  add_index "spree_products", ["name"], name: "index_spree_products_on_name", using: :btree
  add_index "spree_products", ["product_type"], name: "index_spree_products_on_product_type", using: :btree
  add_index "spree_products", ["shipping_category_id"], name: "index_spree_products_on_shipping_category_id", using: :btree
  add_index "spree_products", ["slug"], name: "index_spree_products_on_slug", unique: true, using: :btree
  add_index "spree_products", ["tax_category_id"], name: "index_spree_products_on_tax_category_id", using: :btree

  create_table "spree_products_promotion_rules", id: false, force: :cascade do |t|
    t.integer "product_id"
    t.integer "promotion_rule_id"
  end

  add_index "spree_products_promotion_rules", ["product_id", "promotion_rule_id"], name: "index_spree_products_promotion_rules_on_product_promotion_rule", using: :btree
  add_index "spree_products_promotion_rules", ["product_id"], name: "index_products_promotion_rules_on_product_id", using: :btree
  add_index "spree_products_promotion_rules", ["promotion_rule_id"], name: "index_products_promotion_rules_on_promotion_rule_id", using: :btree

  create_table "spree_products_taxons", force: :cascade do |t|
    t.integer "product_id"
    t.integer "taxon_id"
    t.integer "position"
    t.integer "variant_id"
  end

  add_index "spree_products_taxons", ["position"], name: "index_spree_products_taxons_on_position", using: :btree
  add_index "spree_products_taxons", ["product_id"], name: "index_spree_products_taxons_on_product_id", using: :btree
  add_index "spree_products_taxons", ["taxon_id"], name: "index_spree_products_taxons_on_taxon_id", using: :btree
  add_index "spree_products_taxons", ["variant_id"], name: "index_spree_products_taxons_on_variant_id", using: :btree

  create_table "spree_promotion_action_line_items", force: :cascade do |t|
    t.integer "promotion_action_id"
    t.integer "variant_id"
    t.integer "quantity",            default: 1
  end

  add_index "spree_promotion_action_line_items", ["promotion_action_id"], name: "index_spree_promotion_action_line_items_on_promotion_action_id", using: :btree
  add_index "spree_promotion_action_line_items", ["variant_id"], name: "index_spree_promotion_action_line_items_on_variant_id", using: :btree

  create_table "spree_promotion_actions", force: :cascade do |t|
    t.integer  "promotion_id"
    t.integer  "position"
    t.string   "type"
    t.datetime "deleted_at"
  end

  add_index "spree_promotion_actions", ["deleted_at"], name: "index_spree_promotion_actions_on_deleted_at", using: :btree
  add_index "spree_promotion_actions", ["id", "type"], name: "index_spree_promotion_actions_on_id_and_type", using: :btree
  add_index "spree_promotion_actions", ["promotion_id"], name: "index_spree_promotion_actions_on_promotion_id", using: :btree

  create_table "spree_promotion_categories", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string   "code"
    t.integer  "vendor_id"
  end

  add_index "spree_promotion_categories", ["name"], name: "index_spree_promotion_categories_on_name", using: :btree

  create_table "spree_promotion_rules", force: :cascade do |t|
    t.integer  "promotion_id"
    t.integer  "user_id"
    t.integer  "product_group_id"
    t.string   "type"
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.string   "code"
    t.text     "preferences"
  end

  add_index "spree_promotion_rules", ["code"], name: "index_spree_promotion_rules_on_code", using: :btree
  add_index "spree_promotion_rules", ["product_group_id"], name: "index_promotion_rules_on_product_group_id", using: :btree
  add_index "spree_promotion_rules", ["promotion_id"], name: "index_spree_promotion_rules_on_promotion_id", using: :btree
  add_index "spree_promotion_rules", ["type"], name: "index_spree_promotion_rules_on_type", using: :btree
  add_index "spree_promotion_rules", ["user_id"], name: "index_promotion_rules_on_user_id", using: :btree

  create_table "spree_promotion_rules_accounts", force: :cascade do |t|
    t.integer "account_id"
    t.integer "promotion_rule_id"
  end

  add_index "spree_promotion_rules_accounts", ["account_id", "promotion_rule_id"], name: "index_spree_promotion_rules_accounts_on_account_promotion_rule", using: :btree
  add_index "spree_promotion_rules_accounts", ["account_id"], name: "index_promotion_rules_accounts_on_account_id", using: :btree
  add_index "spree_promotion_rules_accounts", ["promotion_rule_id"], name: "index_promotion_rules_accounts_on_promotion_rule_id", using: :btree

  create_table "spree_promotion_rules_users", id: false, force: :cascade do |t|
    t.integer "user_id"
    t.integer "promotion_rule_id"
  end

  add_index "spree_promotion_rules_users", ["promotion_rule_id"], name: "index_promotion_rules_users_on_promotion_rule_id", using: :btree
  add_index "spree_promotion_rules_users", ["user_id", "promotion_rule_id"], name: "index_spree_promotion_rules_users_on_user_promotion_rule", using: :btree
  add_index "spree_promotion_rules_users", ["user_id"], name: "index_promotion_rules_users_on_user_id", using: :btree

  create_table "spree_promotion_rules_variants", force: :cascade do |t|
    t.integer "variant_id"
    t.integer "promotion_rule_id"
  end

  add_index "spree_promotion_rules_variants", ["promotion_rule_id"], name: "index_promotion_rules_variants_on_promotion_rule_id", using: :btree
  add_index "spree_promotion_rules_variants", ["variant_id", "promotion_rule_id"], name: "index_spree_promotion_rules_variants_on_variant_promotion_rule", using: :btree
  add_index "spree_promotion_rules_variants", ["variant_id"], name: "index_promotion_rules_variants_on_variant_id", using: :btree

  create_table "spree_promotions", force: :cascade do |t|
    t.string   "description"
    t.datetime "expires_at"
    t.datetime "starts_at"
    t.string   "name"
    t.string   "type"
    t.integer  "usage_limit"
    t.string   "match_policy",          default: "all"
    t.string   "code"
    t.boolean  "advertise",             default: true
    t.string   "path"
    t.datetime "created_at",                            null: false
    t.datetime "updated_at",                            null: false
    t.integer  "promotion_category_id"
    t.integer  "vendor_id"
  end

  add_index "spree_promotions", ["advertise"], name: "index_spree_promotions_on_advertise", using: :btree
  add_index "spree_promotions", ["code"], name: "index_spree_promotions_on_code", using: :btree
  add_index "spree_promotions", ["expires_at"], name: "index_spree_promotions_on_expires_at", using: :btree
  add_index "spree_promotions", ["id", "type"], name: "index_spree_promotions_on_id_and_type", using: :btree
  add_index "spree_promotions", ["name"], name: "index_spree_promotions_on_name", using: :btree
  add_index "spree_promotions", ["promotion_category_id"], name: "index_spree_promotions_on_promotion_category_id", using: :btree
  add_index "spree_promotions", ["starts_at"], name: "index_spree_promotions_on_starts_at", using: :btree

  create_table "spree_properties", force: :cascade do |t|
    t.string   "name"
    t.string   "presentation", null: false
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "spree_properties", ["name"], name: "index_spree_properties_on_name", using: :btree
  add_index "spree_properties", ["presentation"], name: "index_spree_properties_on_presentation", using: :btree

  create_table "spree_properties_prototypes", id: false, force: :cascade do |t|
    t.integer "prototype_id"
    t.integer "property_id"
  end

  add_index "spree_properties_prototypes", ["property_id"], name: "index_spree_properties_prototypes_on_property_id", using: :btree
  add_index "spree_properties_prototypes", ["prototype_id", "property_id"], name: "index_spree_properties_prototypes_on_prototype_and_property", using: :btree
  add_index "spree_properties_prototypes", ["prototype_id"], name: "index_spree_properties_prototypes_on_prototype_id", using: :btree

  create_table "spree_prototypes", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "spree_prototypes", ["name"], name: "index_spree_prototypes_on_name", using: :btree

  create_table "spree_refund_reasons", force: :cascade do |t|
    t.string   "name"
    t.boolean  "active",     default: true
    t.boolean  "mutable",    default: true
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "spree_refund_reasons", ["active"], name: "index_spree_refund_reasons_on_active", using: :btree
  add_index "spree_refund_reasons", ["name"], name: "index_spree_refund_reasons_on_name", using: :btree

  create_table "spree_refunds", force: :cascade do |t|
    t.integer  "payment_id"
    t.decimal  "amount",             precision: 10, scale: 2, default: 0, null: false
    t.string   "transaction_id"
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
    t.integer  "refund_reason_id"
    t.integer  "reimbursement_id"
    t.integer  "account_payment_id"
  end

  add_index "spree_refunds", ["account_payment_id"], name: "index_spree_refunds_on_account_payment_id", using: :btree
  add_index "spree_refunds", ["payment_id"], name: "index_spree_refunds_on_payment_id", using: :btree
  add_index "spree_refunds", ["refund_reason_id"], name: "index_refunds_on_refund_reason_id", using: :btree
  add_index "spree_refunds", ["reimbursement_id"], name: "index_spree_refunds_on_reimbursement_id", using: :btree
  add_index "spree_refunds", ["transaction_id"], name: "index_spree_refunds_on_transaction_id", using: :btree

  create_table "spree_reimbursement_credits", force: :cascade do |t|
    t.decimal "amount",           precision: 10, scale: 2, default: 0, null: false
    t.integer "reimbursement_id"
    t.integer "creditable_id"
    t.string  "creditable_type"
  end

  create_table "spree_reimbursement_types", force: :cascade do |t|
    t.string   "name"
    t.boolean  "active",     default: true
    t.boolean  "mutable",    default: true
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
    t.string   "type"
  end

  add_index "spree_reimbursement_types", ["type"], name: "index_spree_reimbursement_types_on_type", using: :btree

  create_table "spree_reimbursements", force: :cascade do |t|
    t.string   "number"
    t.string   "reimbursement_status"
    t.integer  "customer_return_id"
    t.integer  "order_id"
    t.decimal  "total",                precision: 10, scale: 2
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
  end

  add_index "spree_reimbursements", ["customer_return_id"], name: "index_spree_reimbursements_on_customer_return_id", using: :btree
  add_index "spree_reimbursements", ["order_id"], name: "index_spree_reimbursements_on_order_id", using: :btree

  create_table "spree_reps", force: :cascade do |t|
    t.string   "name",       null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "vendor_id"
    t.string   "initials"
  end

  create_table "spree_return_authorization_reasons", force: :cascade do |t|
    t.string   "name"
    t.boolean  "active",     default: true
    t.boolean  "mutable",    default: true
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  add_index "spree_return_authorization_reasons", ["active"], name: "index_spree_return_authorization_reasons_on_active", using: :btree
  add_index "spree_return_authorization_reasons", ["name"], name: "index_spree_return_authorization_reasons_on_name", using: :btree

  create_table "spree_return_authorizations", force: :cascade do |t|
    t.string   "number"
    t.string   "state"
    t.integer  "order_id"
    t.text     "memo"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer  "stock_location_id"
    t.integer  "return_authorization_reason_id"
  end

  add_index "spree_return_authorizations", ["number"], name: "index_spree_return_authorizations_on_number", using: :btree
  add_index "spree_return_authorizations", ["order_id"], name: "index_spree_return_authorizations_on_order_id", using: :btree
  add_index "spree_return_authorizations", ["return_authorization_reason_id"], name: "index_return_authorizations_on_return_authorization_reason_id", using: :btree
  add_index "spree_return_authorizations", ["state"], name: "index_spree_return_authorizations_on_state", using: :btree
  add_index "spree_return_authorizations", ["stock_location_id"], name: "index_spree_return_authorizations_on_stock_location_id", using: :btree

  create_table "spree_return_items", force: :cascade do |t|
    t.integer  "return_authorization_id"
    t.integer  "inventory_unit_id"
    t.integer  "exchange_variant_id"
    t.datetime "created_at",                                                              null: false
    t.datetime "updated_at",                                                              null: false
    t.decimal  "pre_tax_amount",                  precision: 12, scale: 4, default: 0,    null: false
    t.decimal  "included_tax_total",              precision: 12, scale: 4, default: 0,    null: false
    t.decimal  "additional_tax_total",            precision: 12, scale: 4, default: 0,    null: false
    t.string   "reception_status"
    t.string   "acceptance_status"
    t.integer  "customer_return_id"
    t.integer  "reimbursement_id"
    t.integer  "exchange_inventory_unit_id"
    t.text     "acceptance_status_errors"
    t.integer  "preferred_reimbursement_type_id"
    t.integer  "override_reimbursement_type_id"
    t.boolean  "resellable",                                               default: true, null: false
  end

  add_index "spree_return_items", ["customer_return_id"], name: "index_return_items_on_customer_return_id", using: :btree
  add_index "spree_return_items", ["exchange_inventory_unit_id"], name: "index_spree_return_items_on_exchange_inventory_unit_id", using: :btree
  add_index "spree_return_items", ["exchange_variant_id"], name: "index_spree_return_items_on_exchange_variant_id", using: :btree
  add_index "spree_return_items", ["inventory_unit_id"], name: "index_spree_return_items_on_inventory_unit_id", using: :btree
  add_index "spree_return_items", ["override_reimbursement_type_id"], name: "index_spree_return_items_on_override_reimbursement_type_id", using: :btree
  add_index "spree_return_items", ["preferred_reimbursement_type_id"], name: "index_spree_return_items_on_preferred_reimbursement_type_id", using: :btree
  add_index "spree_return_items", ["reimbursement_id"], name: "index_spree_return_items_on_reimbursement_id", using: :btree
  add_index "spree_return_items", ["return_authorization_id"], name: "index_spree_return_items_on_return_authorization_id", using: :btree

  create_table "spree_roles", force: :cascade do |t|
    t.string "name"
  end

  add_index "spree_roles", ["name"], name: "index_spree_roles_on_name", using: :btree

  create_table "spree_roles_users", id: false, force: :cascade do |t|
    t.integer "role_id"
    t.integer "user_id"
  end

  add_index "spree_roles_users", ["role_id", "user_id"], name: "index_spree_roles_users_on_role_id_and_user_id", using: :btree
  add_index "spree_roles_users", ["role_id"], name: "index_spree_roles_users_on_role_id", using: :btree
  add_index "spree_roles_users", ["user_id"], name: "index_spree_roles_users_on_user_id", using: :btree

  create_table "spree_shipments", force: :cascade do |t|
    t.string   "tracking"
    t.string   "number"
    t.decimal  "cost",                 precision: 10, scale: 2, default: 0
    t.datetime "shipped_at"
    t.integer  "order_id"
    t.integer  "address_id"
    t.string   "state"
    t.datetime "created_at",                                                   null: false
    t.datetime "updated_at",                                                   null: false
    t.integer  "stock_location_id"
    t.decimal  "adjustment_total",     precision: 10, scale: 2, default: 0
    t.decimal  "additional_tax_total", precision: 10, scale: 2, default: 0
    t.decimal  "promo_total",          precision: 10, scale: 2, default: 0
    t.decimal  "included_tax_total",   precision: 10, scale: 2, default: 0,    null: false
    t.decimal  "pre_tax_amount",       precision: 12, scale: 4, default: 0,    null: false
    t.integer  "receiver_id"
    t.datetime "received_at"
    t.boolean  "update_taxes",                                  default: true
  end

  add_index "spree_shipments", ["address_id"], name: "index_spree_shipments_on_address_id", using: :btree
  add_index "spree_shipments", ["number"], name: "index_shipments_on_number", using: :btree
  add_index "spree_shipments", ["order_id"], name: "index_spree_shipments_on_order_id", using: :btree
  add_index "spree_shipments", ["receiver_id"], name: "index_spree_shipments_on_receiver_id", using: :btree
  add_index "spree_shipments", ["stock_location_id"], name: "index_spree_shipments_on_stock_location_id", using: :btree

  create_table "spree_shipping_categories", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer  "vendor_id"
  end

  add_index "spree_shipping_categories", ["name"], name: "index_spree_shipping_categories_on_name", using: :btree

  create_table "spree_shipping_groups", force: :cascade do |t|
    t.string  "name",                             null: false
    t.integer "vendor_id"
    t.json    "deliverable_days"
    t.boolean "is_default",       default: false
  end

  add_index "spree_shipping_groups", ["is_default"], name: "index_spree_shipping_groups_on_is_default", using: :btree
  add_index "spree_shipping_groups", ["name"], name: "index_spree_shipping_groups_on_name", using: :btree
  add_index "spree_shipping_groups", ["vendor_id"], name: "index_spree_shipping_groups_on_vendor_id", using: :btree

  create_table "spree_shipping_method_categories", force: :cascade do |t|
    t.integer  "shipping_method_id",   null: false
    t.integer  "shipping_category_id", null: false
    t.datetime "created_at",           null: false
    t.datetime "updated_at",           null: false
  end

  add_index "spree_shipping_method_categories", ["shipping_category_id", "shipping_method_id"], name: "unique_spree_shipping_method_categories", unique: true, using: :btree
  add_index "spree_shipping_method_categories", ["shipping_category_id"], name: "index_spree_shipping_method_categories_on_shipping_category_id", using: :btree
  add_index "spree_shipping_method_categories", ["shipping_method_id"], name: "index_spree_shipping_method_categories_on_shipping_method_id", using: :btree

  create_table "spree_shipping_methods", force: :cascade do |t|
    t.string   "name"
    t.string   "display_on"
    t.datetime "deleted_at"
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "tracking_url"
    t.string   "admin_name"
    t.integer  "tax_category_id"
    t.string   "code"
    t.boolean  "rate_tbd",        default: false
  end

  add_index "spree_shipping_methods", ["deleted_at"], name: "index_spree_shipping_methods_on_deleted_at", using: :btree
  add_index "spree_shipping_methods", ["name"], name: "index_spree_shipping_methods_on_name", using: :btree
  add_index "spree_shipping_methods", ["tax_category_id"], name: "index_spree_shipping_methods_on_tax_category_id", using: :btree

  create_table "spree_shipping_methods_zones", id: false, force: :cascade do |t|
    t.integer "shipping_method_id"
    t.integer "zone_id"
  end

  create_table "spree_shipping_rates", force: :cascade do |t|
    t.integer  "shipment_id"
    t.integer  "shipping_method_id"
    t.boolean  "selected",                                   default: false
    t.decimal  "cost",               precision: 8, scale: 2, default: 0
    t.datetime "created_at",                                                 null: false
    t.datetime "updated_at",                                                 null: false
    t.integer  "tax_rate_id"
  end

  add_index "spree_shipping_rates", ["selected"], name: "index_spree_shipping_rates_on_selected", using: :btree
  add_index "spree_shipping_rates", ["shipment_id", "shipping_method_id"], name: "spree_shipping_rates_join_index", unique: true, using: :btree
  add_index "spree_shipping_rates", ["shipping_method_id"], name: "index_spree_shipping_rates_on_shipping_method_id", using: :btree
  add_index "spree_shipping_rates", ["tax_rate_id"], name: "index_spree_shipping_rates_on_tax_rate_id", using: :btree

  create_table "spree_skrill_transactions", force: :cascade do |t|
    t.string   "email"
    t.float    "amount"
    t.string   "currency"
    t.integer  "transaction_id"
    t.integer  "customer_id"
    t.string   "payment_type"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "spree_standing_line_items", force: :cascade do |t|
    t.integer  "variant_id"
    t.integer  "standing_order_id"
    t.decimal  "quantity",          precision: 15, scale: 5
    t.decimal  "price"
    t.string   "currency"
    t.datetime "created_at",                                              null: false
    t.datetime "updated_at",                                              null: false
    t.string   "pack_size",                                  default: "", null: false
    t.string   "lot_number"
    t.integer  "txn_class_id"
    t.integer  "position"
  end

  add_index "spree_standing_line_items", ["lot_number"], name: "index_spree_standing_line_items_on_lot_number", using: :btree
  add_index "spree_standing_line_items", ["pack_size"], name: "index_spree_standing_line_items_on_pack_size", using: :btree
  add_index "spree_standing_line_items", ["position"], name: "index_spree_standing_line_items_on_position", using: :btree
  add_index "spree_standing_line_items", ["standing_order_id"], name: "index_spree_standing_line_items_on_standing_order_id", using: :btree
  add_index "spree_standing_line_items", ["txn_class_id"], name: "index_spree_standing_line_items_on_txn_class_id", using: :btree
  add_index "spree_standing_line_items", ["variant_id", "standing_order_id"], name: "index_spree_standing_line_items_on_variant_and_standing_order", using: :btree
  add_index "spree_standing_line_items", ["variant_id"], name: "index_spree_standing_line_items_on_variant_id", using: :btree

  create_table "spree_standing_order_schedules", force: :cascade do |t|
    t.integer  "standing_order_id"
    t.integer  "order_id"
    t.datetime "deliver_at"
    t.datetime "remind_at"
    t.datetime "reminded_at"
    t.datetime "create_at"
    t.datetime "created_at"
    t.datetime "process_at"
    t.datetime "processed_at"
    t.boolean  "skip"
    t.boolean  "visible"
  end

  add_index "spree_standing_order_schedules", ["create_at", "skip", "visible"], name: "index_standing_order_schedules_create_skip_visible", using: :btree
  add_index "spree_standing_order_schedules", ["create_at", "skip"], name: "index_spree_standing_order_schedules_on_create_at_and_skip", using: :btree
  add_index "spree_standing_order_schedules", ["create_at", "visible"], name: "index_spree_standing_order_schedules_on_create_at_and_visible", using: :btree
  add_index "spree_standing_order_schedules", ["create_at"], name: "index_spree_standing_order_schedules_on_create_at", using: :btree
  add_index "spree_standing_order_schedules", ["created_at"], name: "index_spree_standing_order_schedules_on_created_at", using: :btree
  add_index "spree_standing_order_schedules", ["deliver_at", "skip", "visible"], name: "index_standing_order_schedules_deliver_skip_visible", using: :btree
  add_index "spree_standing_order_schedules", ["deliver_at", "skip"], name: "index_spree_standing_order_schedules_on_deliver_at_and_skip", using: :btree
  add_index "spree_standing_order_schedules", ["deliver_at", "visible"], name: "index_spree_standing_order_schedules_on_deliver_at_and_visible", using: :btree
  add_index "spree_standing_order_schedules", ["deliver_at"], name: "index_spree_standing_order_schedules_on_deliver_at", using: :btree
  add_index "spree_standing_order_schedules", ["order_id"], name: "index_spree_standing_order_schedules_on_order_id", using: :btree
  add_index "spree_standing_order_schedules", ["process_at", "skip", "visible"], name: "index_standing_order_schedules_process_skip_visible", using: :btree
  add_index "spree_standing_order_schedules", ["process_at", "skip"], name: "index_spree_standing_order_schedules_on_process_at_and_skip", using: :btree
  add_index "spree_standing_order_schedules", ["process_at", "visible"], name: "index_spree_standing_order_schedules_on_process_at_and_visible", using: :btree
  add_index "spree_standing_order_schedules", ["process_at"], name: "index_spree_standing_order_schedules_on_process_at", using: :btree
  add_index "spree_standing_order_schedules", ["processed_at"], name: "index_spree_standing_order_schedules_on_processed_at", using: :btree
  add_index "spree_standing_order_schedules", ["remind_at", "skip", "visible"], name: "index_standing_order_schedules_remind_skip_visible", using: :btree
  add_index "spree_standing_order_schedules", ["remind_at", "skip"], name: "index_spree_standing_order_schedules_on_remind_at_and_skip", using: :btree
  add_index "spree_standing_order_schedules", ["remind_at", "visible"], name: "index_spree_standing_order_schedules_on_remind_at_and_visible", using: :btree
  add_index "spree_standing_order_schedules", ["remind_at"], name: "index_spree_standing_order_schedules_on_remind_at", using: :btree
  add_index "spree_standing_order_schedules", ["reminded_at"], name: "index_spree_standing_order_schedules_on_reminded_at", using: :btree
  add_index "spree_standing_order_schedules", ["skip"], name: "index_spree_standing_order_schedules_on_skip", using: :btree
  add_index "spree_standing_order_schedules", ["standing_order_id"], name: "index_spree_standing_order_schedules_on_standing_order_id", using: :btree
  add_index "spree_standing_order_schedules", ["visible"], name: "index_spree_standing_order_schedules_on_visible", using: :btree

  create_table "spree_standing_order_trackers", force: :cascade do |t|
    t.integer  "standing_order_id"
    t.json     "original"
    t.json     "original_changes"
    t.boolean  "active"
    t.datetime "tracking_since"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "spree_standing_order_trackers", ["active"], name: "index_spree_standing_order_trackers_on_active", using: :btree
  add_index "spree_standing_order_trackers", ["standing_order_id", "active"], name: "index_spree_standing_order_trackers_on_standing_order_active", using: :btree
  add_index "spree_standing_order_trackers", ["standing_order_id"], name: "index_spree_standing_order_trackers_on_standing_order_id", using: :btree
  add_index "spree_standing_order_trackers", ["tracking_since"], name: "index_spree_standing_order_trackers_on_tracking_since", using: :btree

  create_table "spree_standing_orders", force: :cascade do |t|
    t.integer  "user_id"
    t.string   "name"
    t.integer  "frequency_id"
    t.boolean  "frequency_data_1_monday"
    t.boolean  "frequency_data_1_tuesday"
    t.boolean  "frequency_data_1_wednesday"
    t.boolean  "frequency_data_1_thursday"
    t.boolean  "frequency_data_1_friday"
    t.boolean  "frequency_data_1_saturday"
    t.boolean  "frequency_data_1_sunday"
    t.integer  "frequency_data_2_every"
    t.integer  "frequency_data_2_day_of_week"
    t.string   "frequency_data_3_type"
    t.integer  "frequency_data_3_month_number"
    t.integer  "frequency_data_3_week_number"
    t.integer  "frequency_data_3_every"
    t.date     "start_at"
    t.integer  "end_at_id"
    t.integer  "end_at_data_1_after"
    t.date     "end_at_data_2_by"
    t.integer  "timing_id"
    t.boolean  "timing_create"
    t.boolean  "timing_remind"
    t.boolean  "timing_process"
    t.boolean  "timing_approve"
    t.integer  "timing_data_create_days"
    t.integer  "timing_data_create_at_hour"
    t.integer  "timing_data_remind_days"
    t.integer  "timing_data_remind_at_hour"
    t.integer  "timing_data_process_hours"
    t.integer  "timing_data_process_at_hour"
    t.integer  "timing_data_approve_days"
    t.integer  "timing_data_approve_at_hour"
    t.decimal  "total"
    t.decimal  "item_total"
    t.datetime "created_at",                                    null: false
    t.datetime "updated_at",                                    null: false
    t.integer  "account_id"
    t.integer  "shipping_method_id"
    t.integer  "vendor_id"
    t.integer  "customer_id"
    t.integer  "timing_data_process_days"
    t.integer  "txn_class_id"
    t.boolean  "auto_approve",                  default: false
  end

  add_index "spree_standing_orders", ["account_id"], name: "index_spree_standing_orders_on_account_id", using: :btree
  add_index "spree_standing_orders", ["shipping_method_id"], name: "index_spree_standing_orders_on_shipping_method_id", using: :btree
  add_index "spree_standing_orders", ["start_at"], name: "index_spree_standing_orders_on_start_at", using: :btree
  add_index "spree_standing_orders", ["txn_class_id"], name: "index_spree_standing_orders_on_txn_class_id", using: :btree
  add_index "spree_standing_orders", ["user_id"], name: "index_spree_standing_orders_on_user_id", using: :btree

  create_table "spree_state_changes", force: :cascade do |t|
    t.string   "name"
    t.string   "previous_state"
    t.integer  "stateful_id"
    t.integer  "user_id"
    t.string   "stateful_type"
    t.string   "next_state"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
  end

  add_index "spree_state_changes", ["stateful_id", "stateful_type"], name: "index_spree_state_changes_on_stateful_id_and_stateful_type", using: :btree
  add_index "spree_state_changes", ["user_id"], name: "index_spree_state_changes_on_user_id", using: :btree

  create_table "spree_states", force: :cascade do |t|
    t.string   "name"
    t.string   "abbr"
    t.integer  "country_id"
    t.datetime "updated_at"
  end

  add_index "spree_states", ["abbr"], name: "index_spree_states_on_abbr", using: :btree
  add_index "spree_states", ["country_id"], name: "index_spree_states_on_country_id", using: :btree
  add_index "spree_states", ["name"], name: "index_spree_states_on_name", using: :btree

  create_table "spree_stock_item_lots", force: :cascade do |t|
    t.integer "lot_id",                                             null: false
    t.integer "stock_item_id",                                      null: false
    t.decimal "count",         precision: 15, scale: 5, default: 0, null: false
  end

  add_index "spree_stock_item_lots", ["count"], name: "index_spree_stock_item_lots_on_count", using: :btree
  add_index "spree_stock_item_lots", ["lot_id"], name: "index_spree_stock_item_lots_on_lot_id", using: :btree
  add_index "spree_stock_item_lots", ["stock_item_id"], name: "index_spree_stock_item_lots_on_stock_item_id", using: :btree

  create_table "spree_stock_items", force: :cascade do |t|
    t.integer  "stock_location_id"
    t.integer  "variant_id"
    t.decimal  "count_on_hand",     precision: 15, scale: 5, default: 0,    null: false
    t.datetime "created_at",                                                null: false
    t.datetime "updated_at",                                                null: false
    t.boolean  "backorderable",                              default: true
    t.datetime "deleted_at"
    t.decimal  "min_stock_level"
    t.decimal  "on_hand",           precision: 15, scale: 5, default: 0,    null: false
    t.decimal  "committed",         precision: 15, scale: 5, default: 0,    null: false
  end

  add_index "spree_stock_items", ["backorderable"], name: "index_spree_stock_items_on_backorderable", using: :btree
  add_index "spree_stock_items", ["committed"], name: "index_spree_stock_items_on_committed", using: :btree
  add_index "spree_stock_items", ["deleted_at"], name: "index_spree_stock_items_on_deleted_at", using: :btree
  add_index "spree_stock_items", ["min_stock_level"], name: "index_spree_stock_items_on_min_stock_level", using: :btree
  add_index "spree_stock_items", ["on_hand"], name: "index_spree_stock_items_on_on_hand", using: :btree
  add_index "spree_stock_items", ["stock_location_id", "variant_id"], name: "stock_item_by_loc_and_var_id", using: :btree
  add_index "spree_stock_items", ["stock_location_id"], name: "index_spree_stock_items_on_stock_location_id", using: :btree
  add_index "spree_stock_items", ["variant_id"], name: "index_spree_stock_items_on_variant_id", using: :btree

  create_table "spree_stock_locations", force: :cascade do |t|
    t.string   "name"
    t.datetime "created_at",                             null: false
    t.datetime "updated_at",                             null: false
    t.boolean  "default",                default: false, null: false
    t.string   "address1"
    t.string   "address2"
    t.string   "city"
    t.integer  "state_id"
    t.string   "state_name"
    t.integer  "country_id"
    t.string   "zipcode"
    t.string   "phone"
    t.boolean  "active",                 default: true
    t.boolean  "backorderable_default",  default: true
    t.boolean  "propagate_all_variants", default: true
    t.string   "admin_name"
    t.integer  "vendor_id"
  end

  add_index "spree_stock_locations", ["active"], name: "index_spree_stock_locations_on_active", using: :btree
  add_index "spree_stock_locations", ["backorderable_default"], name: "index_spree_stock_locations_on_backorderable_default", using: :btree
  add_index "spree_stock_locations", ["country_id"], name: "index_spree_stock_locations_on_country_id", using: :btree
  add_index "spree_stock_locations", ["default"], name: "index_spree_stock_locations_on_default", using: :btree
  add_index "spree_stock_locations", ["propagate_all_variants"], name: "index_spree_stock_locations_on_propagate_all_variants", using: :btree
  add_index "spree_stock_locations", ["state_id"], name: "index_spree_stock_locations_on_state_id", using: :btree

  create_table "spree_stock_movements", force: :cascade do |t|
    t.integer  "stock_item_id"
    t.decimal  "quantity",        precision: 15, scale: 5, default: 0
    t.string   "action"
    t.datetime "created_at",                                           null: false
    t.datetime "updated_at",                                           null: false
    t.integer  "originator_id"
    t.string   "originator_type"
    t.integer  "lot_id"
  end

  add_index "spree_stock_movements", ["lot_id"], name: "index_spree_stock_movements_on_lot_id", using: :btree
  add_index "spree_stock_movements", ["originator_id", "originator_type"], name: "index_spree_stock_movements_on_originator", using: :btree
  add_index "spree_stock_movements", ["originator_id"], name: "index_spree_stock_movements_on_originator_id", using: :btree
  add_index "spree_stock_movements", ["originator_type"], name: "index_spree_stock_movements_on_originator_type", using: :btree
  add_index "spree_stock_movements", ["stock_item_id"], name: "index_spree_stock_movements_on_stock_item_id", using: :btree

  create_table "spree_stock_transfers", force: :cascade do |t|
    t.string   "type"
    t.string   "reference"
    t.integer  "source_location_id"
    t.integer  "destination_location_id"
    t.datetime "created_at",                              null: false
    t.datetime "updated_at",                              null: false
    t.string   "number"
    t.integer  "company_id"
    t.integer  "general_account_id"
    t.string   "transfer_type"
    t.boolean  "sync",                    default: true
    t.boolean  "with_lots",               default: false
    t.integer  "assembly_lot_id"
    t.text     "note"
  end

  add_index "spree_stock_transfers", ["assembly_lot_id"], name: "index_spree_stock_transfers_on_assembly_lot_id", using: :btree
  add_index "spree_stock_transfers", ["company_id"], name: "index_spree_stock_transfers_on_company_id", using: :btree
  add_index "spree_stock_transfers", ["destination_location_id"], name: "index_spree_stock_transfers_on_destination_location_id", using: :btree
  add_index "spree_stock_transfers", ["number"], name: "index_spree_stock_transfers_on_number", using: :btree
  add_index "spree_stock_transfers", ["source_location_id"], name: "index_spree_stock_transfers_on_source_location_id", using: :btree
  add_index "spree_stock_transfers", ["transfer_type"], name: "index_spree_stock_transfers_on_transfer_type", using: :btree

  create_table "spree_stores", force: :cascade do |t|
    t.string   "name"
    t.string   "url"
    t.text     "meta_description"
    t.text     "meta_keywords"
    t.string   "seo_title"
    t.string   "mail_from_address"
    t.string   "default_currency"
    t.string   "code"
    t.boolean  "default",           default: false, null: false
    t.datetime "created_at",                        null: false
    t.datetime "updated_at",                        null: false
  end

  add_index "spree_stores", ["code"], name: "index_spree_stores_on_code", using: :btree
  add_index "spree_stores", ["default"], name: "index_spree_stores_on_default", using: :btree
  add_index "spree_stores", ["url"], name: "index_spree_stores_on_url", using: :btree

  create_table "spree_tax_categories", force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.boolean  "is_default",  default: false
    t.datetime "deleted_at"
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.string   "tax_code"
    t.integer  "vendor_id"
  end

  add_index "spree_tax_categories", ["deleted_at"], name: "index_spree_tax_categories_on_deleted_at", using: :btree
  add_index "spree_tax_categories", ["is_default"], name: "index_spree_tax_categories_on_is_default", using: :btree
  add_index "spree_tax_categories", ["name"], name: "index_spree_tax_categories_on_name", using: :btree
  add_index "spree_tax_categories", ["vendor_id"], name: "index_spree_tax_categories_on_vendor_id", using: :btree

  create_table "spree_tax_cloud_cart_items", force: :cascade do |t|
    t.integer  "index"
    t.integer  "tic"
    t.string   "sku"
    t.integer  "quantity"
    t.decimal  "price",                    precision: 8,  scale: 2, default: 0
    t.decimal  "amount",                   precision: 13, scale: 5, default: 0
    t.decimal  "ship_total",               precision: 10, scale: 2, default: 0
    t.integer  "line_item_id"
    t.integer  "tax_cloud_transaction_id"
    t.string   "type"
    t.datetime "created_at",                                                    null: false
    t.datetime "updated_at",                                                    null: false
  end

  add_index "spree_tax_cloud_cart_items", ["line_item_id"], name: "index_spree_tax_cloud_cart_items_on_line_item_id", using: :btree
  add_index "spree_tax_cloud_cart_items", ["tax_cloud_transaction_id"], name: "index_spree_tax_cloud_cart_items_on_tax_cloud_transaction_id", using: :btree

  create_table "spree_tax_cloud_transactions", force: :cascade do |t|
    t.integer  "order_id"
    t.string   "message"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "spree_tax_cloud_transactions", ["order_id"], name: "index_spree_tax_cloud_transactions_on_order_id", using: :btree

  create_table "spree_tax_rates", force: :cascade do |t|
    t.decimal  "amount",             precision: 8, scale: 5
    t.integer  "zone_id"
    t.integer  "tax_category_id"
    t.boolean  "included_in_price",                          default: false
    t.datetime "created_at",                                                 null: false
    t.datetime "updated_at",                                                 null: false
    t.string   "name"
    t.boolean  "show_rate_in_label",                         default: true
    t.datetime "deleted_at"
  end

  add_index "spree_tax_rates", ["deleted_at"], name: "index_spree_tax_rates_on_deleted_at", using: :btree
  add_index "spree_tax_rates", ["included_in_price"], name: "index_spree_tax_rates_on_included_in_price", using: :btree
  add_index "spree_tax_rates", ["show_rate_in_label"], name: "index_spree_tax_rates_on_show_rate_in_label", using: :btree
  add_index "spree_tax_rates", ["tax_category_id"], name: "index_spree_tax_rates_on_tax_category_id", using: :btree
  add_index "spree_tax_rates", ["zone_id"], name: "index_spree_tax_rates_on_zone_id", using: :btree

  create_table "spree_taxonomies", force: :cascade do |t|
    t.string   "name",                   null: false
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
    t.integer  "position",   default: 0
    t.integer  "vendor_id"
  end

  add_index "spree_taxonomies", ["name"], name: "index_spree_taxonomies_on_name", using: :btree
  add_index "spree_taxonomies", ["position"], name: "index_spree_taxonomies_on_position", using: :btree

  create_table "spree_taxons", force: :cascade do |t|
    t.integer  "parent_id"
    t.integer  "position",          default: 0
    t.string   "name",                          null: false
    t.string   "permalink"
    t.integer  "taxonomy_id"
    t.integer  "lft"
    t.integer  "rgt"
    t.string   "icon_file_name"
    t.string   "icon_content_type"
    t.integer  "icon_file_size"
    t.datetime "icon_updated_at"
    t.text     "description"
    t.datetime "created_at",                    null: false
    t.datetime "updated_at",                    null: false
    t.string   "meta_title"
    t.string   "meta_description"
    t.string   "meta_keywords"
    t.integer  "depth"
    t.integer  "vendor_id"
  end

  add_index "spree_taxons", ["name"], name: "index_spree_taxons_on_name", using: :btree
  add_index "spree_taxons", ["parent_id"], name: "index_taxons_on_parent_id", using: :btree
  add_index "spree_taxons", ["permalink"], name: "index_taxons_on_permalink", using: :btree
  add_index "spree_taxons", ["position"], name: "index_spree_taxons_on_position", using: :btree
  add_index "spree_taxons", ["taxonomy_id"], name: "index_taxons_on_taxonomy_id", using: :btree

  create_table "spree_taxons_promotion_rules", force: :cascade do |t|
    t.integer "taxon_id"
    t.integer "promotion_rule_id"
  end

  add_index "spree_taxons_promotion_rules", ["promotion_rule_id"], name: "index_spree_taxons_promotion_rules_on_promotion_rule_id", using: :btree
  add_index "spree_taxons_promotion_rules", ["taxon_id", "promotion_rule_id"], name: "index_spree_taxons_promotion_rules_on_taxon_promotion_rule", using: :btree
  add_index "spree_taxons_promotion_rules", ["taxon_id"], name: "index_spree_taxons_promotion_rules_on_taxon_id", using: :btree

  create_table "spree_taxons_prototypes", force: :cascade do |t|
    t.integer "taxon_id"
    t.integer "prototype_id"
  end

  add_index "spree_taxons_prototypes", ["prototype_id"], name: "index_spree_taxons_prototypes_on_prototype_id", using: :btree
  add_index "spree_taxons_prototypes", ["taxon_id", "prototype_id"], name: "index_spree_taxons_prototypes_on_taxon_id_and_prototype_id", using: :btree
  add_index "spree_taxons_prototypes", ["taxon_id"], name: "index_spree_taxons_prototypes_on_taxon_id", using: :btree

  create_table "spree_trackers", force: :cascade do |t|
    t.string   "analytics_id"
    t.boolean  "active",       default: true
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
  end

  add_index "spree_trackers", ["active"], name: "index_spree_trackers_on_active", using: :btree
  add_index "spree_trackers", ["analytics_id"], name: "index_spree_trackers_on_analytics_id", using: :btree

  create_table "spree_transaction_classes", force: :cascade do |t|
    t.string  "name"
    t.integer "parent_id"
    t.integer "vendor_id"
    t.string  "fully_qualified_name"
  end

  add_index "spree_transaction_classes", ["fully_qualified_name"], name: "index_spree_transaction_classes_on_fully_qualified_name", using: :btree
  add_index "spree_transaction_classes", ["parent_id"], name: "index_spree_transaction_classes_on_parent_id", using: :btree
  add_index "spree_transaction_classes", ["vendor_id"], name: "index_spree_transaction_classes_on_vendor_id", using: :btree

  create_table "spree_user_accounts", force: :cascade do |t|
    t.integer  "account_id", null: false
    t.integer  "user_id",    null: false
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "spree_user_accounts", ["account_id"], name: "index_spree_user_accounts_on_account_id", using: :btree
  add_index "spree_user_accounts", ["user_id"], name: "index_spree_user_accounts_on_user_id", using: :btree

  create_table "spree_users", force: :cascade do |t|
    t.string   "encrypted_password",     limit: 128
    t.string   "password_salt",          limit: 128
    t.string   "email"
    t.string   "remember_token"
    t.string   "persistence_token"
    t.string   "reset_password_token"
    t.string   "perishable_token"
    t.integer  "sign_in_count",                      default: 0,     null: false
    t.integer  "failed_attempts",                    default: 0,     null: false
    t.datetime "last_request_at"
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.string   "login"
    t.integer  "ship_address_id"
    t.integer  "bill_address_id"
    t.string   "authentication_token"
    t.string   "unlock_token"
    t.datetime "locked_at"
    t.datetime "reset_password_sent_at"
    t.datetime "created_at",                                         null: false
    t.datetime "updated_at",                                         null: false
    t.string   "spree_api_key",          limit: 48
    t.datetime "remember_created_at"
    t.datetime "deleted_at"
    t.string   "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string   "firstname"
    t.string   "lastname"
    t.string   "phone"
    t.string   "position"
    t.boolean  "customer_admin",                     default: false
    t.hstore   "settings",                           default: {},    null: false
    t.json     "comms_settings"
    t.integer  "company_id"
    t.jsonb    "permissions"
    t.integer  "permission_group_id"
  end

  add_index "spree_users", ["deleted_at"], name: "index_spree_users_on_deleted_at", using: :btree
  add_index "spree_users", ["email"], name: "email_idx_unique", unique: true, using: :btree
  add_index "spree_users", ["permission_group_id"], name: "index_spree_users_on_permission_group_id", using: :btree
  add_index "spree_users", ["spree_api_key"], name: "index_spree_users_on_spree_api_key", using: :btree

  create_table "spree_variant_vendors", force: :cascade do |t|
    t.integer  "account_id"
    t.integer  "variant_id"
    t.decimal  "cost_price", precision: 10, scale: 2, default: 0, null: false
    t.string   "sku"
    t.string   "name"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  add_index "spree_variant_vendors", ["account_id"], name: "index_spree_variant_vendors_on_account_id", using: :btree
  add_index "spree_variant_vendors", ["name"], name: "index_spree_variant_vendors_on_name", using: :btree
  add_index "spree_variant_vendors", ["variant_id"], name: "index_spree_variant_vendors_on_variant_id", using: :btree

  create_table "spree_variants", force: :cascade do |t|
    t.string   "sku",                                                  default: "",      null: false
    t.decimal  "weight",                      precision: 8,  scale: 2, default: 0
    t.decimal  "height",                      precision: 8,  scale: 2
    t.decimal  "width",                       precision: 8,  scale: 2
    t.decimal  "depth",                       precision: 8,  scale: 2
    t.datetime "deleted_at"
    t.boolean  "is_master",                                            default: false
    t.integer  "product_id"
    t.decimal  "cost_price",                  precision: 10, scale: 2, default: 0,       null: false
    t.integer  "position"
    t.string   "cost_currency"
    t.boolean  "track_inventory",                                      default: true
    t.integer  "tax_category_id"
    t.datetime "updated_at"
    t.integer  "stock_items_count",                                    default: 0,       null: false
    t.integer  "lead_time",                                            default: 1,       null: false
    t.string   "pack_size",                                            default: "",      null: false
    t.string   "weight_units"
    t.integer  "general_account_id"
    t.integer  "income_account_id"
    t.integer  "cogs_account_id"
    t.integer  "asset_account_id"
    t.integer  "expense_account_id"
    t.string   "variant_type"
    t.string   "dimension_units"
    t.datetime "discontinued_on"
    t.jsonb    "custom_attrs"
    t.integer  "pack_size_qty"
    t.string   "fully_qualified_name"
    t.integer  "minimum_order_quantity",                               default: 0,       null: false
    t.text     "variant_description"
    t.boolean  "lot_tracking",                                         default: false
    t.boolean  "show_parts",                                           default: false,   null: false
    t.integer  "txn_class_id"
    t.decimal  "incremental_order_quantity",  precision: 15, scale: 5, default: 1,       null: false
    t.boolean  "visible_to_all",                                       default: false,   null: false
    t.string   "display_name",                                         default: "",      null: false
    t.string   "default_display_name"
    t.string   "full_display_name"
    t.string   "costing_method",                                       default: "fixed", null: false
    t.decimal  "avg_cost_price",              precision: 10, scale: 2, default: 0,       null: false
    t.decimal  "last_cost_price",             precision: 10, scale: 2, default: 0,       null: false
    t.decimal  "sum_cost_price",              precision: 10, scale: 2, default: 0,       null: false
    t.integer  "preferred_vendor_account_id"
    t.boolean  "purchase_from_any",                                    default: true,    null: false
    t.string   "text_options"
  end

  add_index "spree_variants", ["costing_method"], name: "index_spree_variants_on_costing_method", using: :btree
  add_index "spree_variants", ["default_display_name"], name: "index_spree_variants_on_default_display_name", using: :btree
  add_index "spree_variants", ["deleted_at", "is_master", "product_id"], name: "index_spree_variants_on_deleted_at_and_is_master_and_product_id", using: :btree
  add_index "spree_variants", ["deleted_at", "product_id"], name: "index_spree_variants_on_deleted_at_and_product_id", using: :btree
  add_index "spree_variants", ["deleted_at"], name: "index_spree_variants_on_deleted_at", using: :btree
  add_index "spree_variants", ["discontinued_on"], name: "index_spree_variants_on_discontinued_on", using: :btree
  add_index "spree_variants", ["display_name"], name: "index_spree_variants_on_display_name", using: :btree
  add_index "spree_variants", ["full_display_name"], name: "index_spree_variants_on_full_display_name", using: :btree
  add_index "spree_variants", ["fully_qualified_name"], name: "index_spree_variants_on_fully_qualified_name", using: :btree
  add_index "spree_variants", ["is_master"], name: "index_spree_variants_on_is_master", using: :btree
  add_index "spree_variants", ["position"], name: "index_spree_variants_on_position", using: :btree
  add_index "spree_variants", ["product_id"], name: "index_spree_variants_on_product_id", using: :btree
  add_index "spree_variants", ["purchase_from_any"], name: "index_spree_variants_on_purchase_from_any", using: :btree
  add_index "spree_variants", ["sku"], name: "index_spree_variants_on_sku", using: :btree
  add_index "spree_variants", ["tax_category_id"], name: "index_spree_variants_on_tax_category_id", using: :btree
  add_index "spree_variants", ["track_inventory"], name: "index_spree_variants_on_track_inventory", using: :btree
  add_index "spree_variants", ["txn_class_id"], name: "index_spree_variants_on_txn_class_id", using: :btree

  create_table "spree_vendor_imports", force: :cascade do |t|
    t.integer  "company_id"
    t.string   "file_file_name"
    t.string   "file_content_type"
    t.integer  "file_file_size"
    t.datetime "file_updated_at"
    t.string   "encoding"
    t.string   "delimer"
    t.boolean  "replace"
    t.integer  "status"
    t.json     "verify_result"
    t.json     "import_result"
    t.boolean  "proceed"
    t.boolean  "proceed_verified"
    t.text     "exception_message"
    t.datetime "created_at",        null: false
    t.datetime "updated_at",        null: false
  end

  add_index "spree_vendor_imports", ["company_id"], name: "index_spree_vendor_imports_on_company_id", using: :btree

  create_table "spree_versions", force: :cascade do |t|
    t.string   "item_type",      null: false
    t.integer  "item_id",        null: false
    t.string   "event",          null: false
    t.string   "whodunnit"
    t.text     "object"
    t.datetime "created_at"
    t.integer  "transaction_id"
  end

  add_index "spree_versions", ["created_at"], name: "index_spree_versions_on_created_at", using: :btree
  add_index "spree_versions", ["item_type", "item_id", "created_at"], name: "index_spree_versions_on_item_type_and_item_id_and_created_at", using: :btree
  add_index "spree_versions", ["item_type", "item_id"], name: "index_spree_versions_on_item_type_and_item_id", using: :btree
  add_index "spree_versions", ["transaction_id"], name: "index_spree_versions_on_transaction_id", using: :btree

  create_table "spree_zone_members", force: :cascade do |t|
    t.integer  "zoneable_id"
    t.string   "zoneable_type"
    t.integer  "zone_id"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "spree_zone_members", ["zone_id"], name: "index_spree_zone_members_on_zone_id", using: :btree
  add_index "spree_zone_members", ["zoneable_id", "zoneable_type"], name: "index_spree_zone_members_on_zoneable_id_and_zoneable_type", using: :btree

  create_table "spree_zones", force: :cascade do |t|
    t.string   "name"
    t.string   "description"
    t.boolean  "default_tax",        default: false
    t.integer  "zone_members_count", default: 0
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
    t.string   "kind"
    t.integer  "vendor_id"
  end

  add_index "spree_zones", ["default_tax"], name: "index_spree_zones_on_default_tax", using: :btree
  add_index "spree_zones", ["kind"], name: "index_spree_zones_on_kind", using: :btree
  add_index "spree_zones", ["vendor_id"], name: "index_spree_zones_on_vendor_id", using: :btree

  create_table "version_associations", force: :cascade do |t|
    t.integer "version_id"
    t.string  "foreign_key_name", null: false
    t.integer "foreign_key_id"
  end

  add_index "version_associations", ["foreign_key_name", "foreign_key_id"], name: "index_version_associations_on_foreign_key", using: :btree
  add_index "version_associations", ["version_id"], name: "index_version_associations_on_version_id", using: :btree

  create_table "versions", force: :cascade do |t|
    t.string   "item_type",            null: false
    t.integer  "item_id",              null: false
    t.string   "event",                null: false
    t.string   "whodunnit"
    t.jsonb    "object"
    t.datetime "created_at"
    t.jsonb    "object_changes"
    t.integer  "transaction_id"
    t.string   "controller"
    t.string   "action"
    t.string   "commit"
    t.jsonb    "params"
    t.string   "transaction_group_id"
  end

  add_index "versions", ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id", using: :btree
  add_index "versions", ["transaction_id"], name: "index_versions_on_transaction_id", using: :btree

end
