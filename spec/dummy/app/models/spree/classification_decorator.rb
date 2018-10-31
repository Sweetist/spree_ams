Spree::Classification.class_eval do
  include Spree::Dirtyable
  belongs_to :variant, class_name: 'Spree::Variant', inverse_of: :classifications, touch: true
  before_validation :erase_validations

  validates_uniqueness_of :taxon_id, scope: %w[product_id variant_id], message: :already_linked

  def erase_validations
    _validators[:taxon_id].first.attributes.delete(:taxon_id)
  end
end
