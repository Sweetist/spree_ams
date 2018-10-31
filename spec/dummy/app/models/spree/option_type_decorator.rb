Spree::OptionType.class_eval do
  clear_validators!
  with_options presence: true do
    validates :name, uniqueness: { scope: :vendor_id, allow_blank: true }
    validates :presentation, uniqueness: { scope: :vendor_id }
  end
  validates_associated :option_values

  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  accepts_nested_attributes_for :option_values, allow_destroy: true
  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  has_many :variants, through: :option_values, source: :variants
  before_destroy :ensure_no_products, prepend: true

  def variants_product_count
    self.variants.pluck(:product_id).uniq.count
  end

  def errors_including_option_values
    self.errors.full_messages + self.option_values.map{|ov| ov.errors.full_messages }.flatten
  end

  def dom_id
    "option_type_#{self.presentation.to_s.gsub(' ', '_').downcase}"
  end

  private

  def ensure_no_products
    count = variants_product_count
    return true if count == 0

    self.errors.add(:base, "Option Type #{self.presentation} is being used by #{count} #{'product'.pluralize(count)} and cannot be deleted.")

    false
  end
end
