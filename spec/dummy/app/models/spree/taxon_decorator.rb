Spree::Taxon.class_eval do
  self.whitelisted_ransackable_attributes = %w[name]
  self.whitelisted_ransackable_associations = %w[vendor]

  belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id

  has_and_belongs_to_many :promotion_rules, class_name: 'Spree::PromotionRule', join_table: 'spree_taxons_promotion_rules', foreign_key: 'taxon_id'
  has_many :promotions, through: :promotion_rules
  has_many :variants, through: :classifications
  before_destroy :update_promotions
  after_create :assign_vendor

  def update_promotions
    self.promotions.unadvertised.find_in_batches do |promo_group|
      # Wait for taxon to be deleted
      Sidekiq::Client.push('at' => Time.current.to_i + 2.seconds, 'class' => TaxonPromotionsWorker, 'queue' => 'critical', 'args' => [self.vendor_id, promo_group.map{|promo| promo.id}])
    end
  end

  def assign_vendor
    self.update_columns(vendor_id: self.taxonomy.try(:vendor_id)) unless self.vendor_id
  end

  def pretty_name
    (self.ancestors.where.not(parent_id: nil).pluck(:name) << name).join(' -> ')
  end

end
