class AddExecutionBacktraceToSpreeIntegrationActions < ActiveRecord::Migration
  def change
    add_column :spree_integration_actions, :execution_backtrace, :text
  end
end
