Spree::OptionValue.class_eval do
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id

  clear_validators!
  with_options presence: true do
    validates :presentation, uniqueness: {scope: [:vendor_id, :option_type_id]}
  end
  validates :name, uniqueness: { scope: [:vendor_id, :option_type_id], allow_blank: true }
  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  after_update :update_variants

  def update_variants
    if self.presentation_changed?
      self.variants.each do |variant|
        variant.set_fully_qualified_name
        variant.notify_integration
      end
    end
  end
end
