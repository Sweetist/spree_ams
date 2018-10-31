class Spree::VariantVendor < Spree::Base
  belongs_to :variant, class_name: 'Spree::Variant', foreign_key: :variant_id, primary_key: :id
  belongs_to :vendor_account, class_name: 'Spree::Account', foreign_key: :account_id, primary_key: :id

  validates :variant_id, :account_id, presence: true
  validates :variant_id, uniqueness: { scope: :account_id }
  validates :cost_price, numericality: { greater_than_or_equal_to: 0 }

  before_create :copy_variant

  def copy_variant(options = {})
    return unless variant
    self.cost_price = variant.current_cost_price if self.cost_price.zero?
    self.name = options[:nest_name] ? variant.full_display_name : variant.default_display_name
  end

end
