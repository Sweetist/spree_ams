class AddDefaultToCommentShareLevel < ActiveRecord::Migration
  def up
    change_column_default(:commontator_comments, :share_level, 'internal')
  end
end
