Spree::PromotionCategory.class_eval do
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id

  self.whitelisted_ransackable_attributes = %w{name}

  private

  def self.find_or_create_account_promotion_category(vendor)
    cat = Spree::PromotionCategory.find_by_name("#{vendor.name} Account Discounts")
    return cat.id unless cat.nil?
    promo_cat = vendor.promotion_categories.create(name: "#{vendor.name} Account Discounts")
    promo_cat.id
  end
end
