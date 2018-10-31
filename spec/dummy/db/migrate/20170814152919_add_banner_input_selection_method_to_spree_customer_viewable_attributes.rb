class AddBannerInputSelectionMethodToSpreeCustomerViewableAttributes < ActiveRecord::Migration
  def change
    add_column :spree_customer_viewable_attributes, :banner_inp_sel_method, :string
  end
end
