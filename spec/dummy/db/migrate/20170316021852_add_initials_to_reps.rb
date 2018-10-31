class AddInitialsToReps < ActiveRecord::Migration
  def change
    add_column :spree_reps, :initials, :string
  end
end
