class ChangeQuantityOnInventoryChangeHistory < ActiveRecord::Migration
  def up
    execute <<-SQL
        ALTER TABLE inventory_change_histories ADD COLUMN quantity_new decimal(15,5);
        UPDATE inventory_change_histories SET quantity_new = quantity;
        ALTER TABLE inventory_change_histories DROP COLUMN quantity;
        ALTER TABLE inventory_change_histories RENAME COLUMN quantity_new TO quantity;
    SQL
  end

  def down
    execute <<-SQL
      ALTER TABLE inventory_change_histories ADD COLUMN quantity_new decimal(12,2);
      UPDATE inventory_change_histories SET quantity_new = quantity;
      ALTER TABLE inventory_change_histories DROP COLUMN quantity;
      ALTER TABLE inventory_change_histories RENAME COLUMN quantity_new TO quantity;
    SQL
  end
end
