class ChangeCreditLimitNullAndDefault < ActiveRecord::Migration
  def up
    change_column_null :spree_accounts, :credit_limit, true
    change_column_default :spree_accounts, :credit_limit, nil
  end
  def down
    change_column_default :spree_accounts, :credit_limit, 0
    change_column_null :spree_accounts, :credit_limit, false
  end
end
