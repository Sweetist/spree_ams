class AddShareLevelToComments < ActiveRecord::Migration
  def change
    add_column :commontator_comments, :share_level, :string 
  end
end
