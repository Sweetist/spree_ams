class ChangeQuantityOnHandOnInventoryChangeHistory < ActiveRecord::Migration
  def up
    execute <<-SQL
        ALTER TABLE inventory_change_histories ADD COLUMN quantity_on_hand_new decimal(15,5);
        UPDATE inventory_change_histories SET quantity_on_hand_new = quantity_on_hand;
        ALTER TABLE inventory_change_histories DROP COLUMN quantity_on_hand;
        ALTER TABLE inventory_change_histories RENAME COLUMN quantity_on_hand_new TO quantity_on_hand;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE inventory_change_histories ADD COLUMN quantity_on_hand_new decimal(12,2);
      UPDATE inventory_change_histories SET quantity_on_hand_new = quantity_on_hand;
      ALTER TABLE inventory_change_histories DROP COLUMN quantity_on_hand;
      ALTER TABLE inventory_change_histories RENAME COLUMN quantity_on_hand_new TO quantity_on_hand;
    SQL
  end
end
