module Spree
  class OptionValuesVariant < Spree::Base
    include Spree::Integrationable
    belongs_to :variant, class_name: 'Spree::Variant', foreign_key: :variant_id, primary_key: :id
    belongs_to :option_value, class_name: 'Spree::OptionValue', foreign_key: :option_value_id, primary_key: :id
    has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  end
end
