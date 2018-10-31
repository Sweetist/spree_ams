Spree::Price.class_eval do
  include Spree::Dirtyable
  # self.whitelisted_ransackable_associations = %w[option_values product prices default_price]
  self.whitelisted_ransackable_attributes = %w[currency amount]
end
