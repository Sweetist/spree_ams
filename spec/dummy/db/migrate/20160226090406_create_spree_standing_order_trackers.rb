class CreateSpreeStandingOrderTrackers < ActiveRecord::Migration
  def change
    create_table :spree_standing_order_trackers do |t|
      t.references :standing_order
      t.json       :original
      t.json       :original_changes
      t.boolean    :active
      t.datetime   :tracking_since
      t.timestamps null: false
    end
  end
end
