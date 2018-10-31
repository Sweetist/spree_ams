Spree::TaxCategory.class_eval do
  include Spree::Integrationable

  clear_validators! #needed to customize the uniquenss validation
  validates :name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true, scope: [:vendor_id, :deleted_at]}
  validates :tax_code, presence: true, length: { maximum: 3 }
  self.whitelisted_ransackable_attributes = %w{name}
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  has_many :accounts, class_name: 'Spree::Account', foreign_key: :tax_category_id, primary_key: :id

  def cat_and_vendor_name
    if self.vendor_id == nil
      "#{self.name} - Default"
    else
      "#{self.name} - #{self.vendor.try(:name)}"
    end
  end

  # method returns whether tax category is assigned to other objects
  # does not include line items
  def is_in_use?
    Spree::Product.where(tax_category_id:self.id).present? || Spree::Variant.where(tax_category_id:self.id).present? || Spree::TaxRate.where(tax_category_id:self.id).present? || Spree::ShippingMethod.where(tax_category_id:self.id).present?
  end

  # method to prep a tax category for deletion by transitioning objects who are associated with one tax category to be associated
  # with a new one (so the former tax category can be deleted safely)
  def prep_for_deletion (new_tax_category_id)
    Spree::Product.where(tax_category_id: self.id).update_all(tax_category_id: new_tax_category_id)
    Spree::Variant.where(tax_category_id: self.id).update_all(tax_category_id: new_tax_category_id)
    Spree::ShippingMethod.where(tax_category_id: self.id).update_all(tax_category_id: new_tax_category_id)
    Spree::TaxRate.where(tax_category_id: self.id).update_all(tax_category_id: new_tax_category_id)
    return true
  end

end
