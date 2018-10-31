class AddVisibleToStandingOrderSchedules < ActiveRecord::Migration
  def change
    add_column :spree_standing_order_schedules, :visible, :boolean

    add_index :spree_standing_order_schedules, :visible
    add_index :spree_standing_order_schedules, [:deliver_at, :visible]
    add_index :spree_standing_order_schedules, [:remind_at, :visible]
    add_index :spree_standing_order_schedules, [:create_at, :visible]
    add_index :spree_standing_order_schedules, [:process_at, :visible]
    add_index :spree_standing_order_schedules, [:deliver_at, :skip, :visible], name: 'index_standing_order_schedules_deliver_skip_visible'
    add_index :spree_standing_order_schedules, [:remind_at, :skip, :visible], name: 'index_standing_order_schedules_remind_skip_visible'
    add_index :spree_standing_order_schedules, [:create_at, :skip, :visible], name: 'index_standing_order_schedules_create_skip_visible'
    add_index :spree_standing_order_schedules, [:process_at, :skip, :visible], name: 'index_standing_order_schedules_process_skip_visible'

    # make them all visible:true (default value)
    reversible do |direction|
      direction.up { Spree::StandingOrderSchedule.all.each {|p| p.save } }
    end

  end
end
