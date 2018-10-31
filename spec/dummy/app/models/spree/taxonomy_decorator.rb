Spree::Taxonomy.class_eval do
  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
  self.whitelisted_ransackable_associations = %w[vendor taxons]
end
