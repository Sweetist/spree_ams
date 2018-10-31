class CreateStandingOrders < ActiveRecord::Migration
  def change
    create_table  :spree_standing_orders do |t|
      t.references :vendor
      t.references :customer
      t.references :user
      t.string     :name
      t.integer    :frequency_id
      t.boolean    :frequency_data_1_monday
      t.boolean    :frequency_data_1_tuesday
      t.boolean    :frequency_data_1_wednesday
      t.boolean    :frequency_data_1_thursday
      t.boolean    :frequency_data_1_friday
      t.boolean    :frequency_data_1_saturday
      t.boolean    :frequency_data_1_sunday
      t.integer    :frequency_data_2_every
      t.integer    :frequency_data_2_day_of_week
      t.string     :frequency_data_3_type
      t.integer    :frequency_data_3_month_number
      t.integer    :frequency_data_3_week_number
      t.integer    :frequency_data_3_every
      t.date       :start_at
      t.integer    :end_at_id
      t.integer    :end_at_data_1_after
      t.date       :end_at_data_2_by
      t.integer    :timing_id
      t.boolean    :timing_create
      t.boolean    :timing_remind
      t.boolean    :timing_process
      t.boolean    :timing_approve
      t.integer    :timing_data_create_days
      t.integer    :timing_data_create_at_hour
      t.integer    :timing_data_remind_days
      t.integer    :timing_data_remind_at_hour
      t.integer    :timing_data_process_hours
      t.integer    :timing_data_process_at_hour
      t.integer    :timing_data_approve_days
      t.integer    :timing_data_approve_at_hour
      t.decimal    :total
      t.decimal    :item_total
      t.timestamps null: false
    end

    add_index :spree_standing_orders, :vendor_id
    add_index :spree_standing_orders, :customer_id
    add_index :spree_standing_orders, :user_id
    add_index :spree_standing_orders, :start_at
  end
end
