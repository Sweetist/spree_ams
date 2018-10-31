class CreateStandingOrderSchedules < ActiveRecord::Migration
  def change
    create_table  :spree_standing_order_schedules do |t|
      t.references :standing_order
      t.references :order
      t.datetime   :deliver_at
      t.datetime   :remind_at
      t.datetime   :reminded_at
      t.datetime   :create_at
      t.datetime   :created_at
      t.datetime   :process_at
      t.datetime   :processed_at
      t.boolean    :skip
    end

    add_index :spree_standing_order_schedules, :standing_order_id
    add_index :spree_standing_order_schedules, :order_id
    add_index :spree_standing_order_schedules, :deliver_at
    add_index :spree_standing_order_schedules, :remind_at
    add_index :spree_standing_order_schedules, :reminded_at
    add_index :spree_standing_order_schedules, :create_at
    add_index :spree_standing_order_schedules, :created_at
    add_index :spree_standing_order_schedules, :process_at
    add_index :spree_standing_order_schedules, :processed_at
    add_index :spree_standing_order_schedules, :skip
    add_index :spree_standing_order_schedules, [:deliver_at, :skip]
    add_index :spree_standing_order_schedules, [:remind_at, :skip]
    add_index :spree_standing_order_schedules, [:create_at, :skip]
    add_index :spree_standing_order_schedules, [:process_at, :skip]
  end
end
