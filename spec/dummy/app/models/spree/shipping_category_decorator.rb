Spree::ShippingCategory.class_eval do
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  # remove old shipping category id from ids array add new to ids array
  def prep_for_deletion (old_id, new_id, vender_id)
    @vendor = Spree::Company.where(id: vender_id).first
    @products = @vendor.products.where(shipping_category_id: old_id).update_all(shipping_category_id: new_id)
    @vendor.shipping_methods.each do |shipping_method|
      if shipping_method.shipping_category_ids.include? old_id
        shipping_method.shipping_category_ids -= [old_id]
      end
      unless shipping_method.shipping_category_ids.include? new_id
        shipping_method.shipping_category_ids += [new_id]
      end
    end
    true
  end

end
