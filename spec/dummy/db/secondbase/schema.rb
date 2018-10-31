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

ActiveRecord::Schema.define(version: 20171130165412) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

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

end
