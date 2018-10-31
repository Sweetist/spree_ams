Spree::StockTransfer.class_eval do
  include Spree::Integrationable
  belongs_to :company, class_name: 'Spree::Company',
                       foreign_key: :company_id,
                       primary_key: :id

  belongs_to :assembly_lot, class_name: 'Spree::Lot', foreign_key: :assembly_lot_id, primary_key: :id

  attr_accessor :is_transfer

  has_many :integration_sync_matches, as: :integration_syncable, class_name: 'Spree::IntegrationSyncMatch', dependent: :destroy
  has_many :integration_actions, as: :integrationable, class_name: 'Spree::IntegrationAction'

  has_paper_trail class_name: 'Spree::Version'

  before_validation :set_transfer_type, on: :create

  validates :transfer_type, :destination_location_id,
            presence: true,
            unless: :with_lots

  validate :src_dest_values,
           on: :update,
           unless: :with_lots

  def notify_integration
    return unless self.sync?
    return unless company && company.integration_items.where(variant_sync: true).present?
    Sidekiq::Client.push(
      'class' => StockTransferSync,
      'queue' => 'integrations',
      'args' => [id, company_id]
    )
  end

  def stock_items_for(stock_location)
    movements = stock_movements
                .select { |sm| sm.stock_location == stock_location }
                .uniq
    return [] unless movements.any?
    movements.map(&:stock_item)
  end

  def display_number
    number
  end

  def display_transfer_type
    "#{self.transfer_type.to_s.titleize}"
  end

  def name_for_integration
    "Stock #{self.transfer_type.to_s.titleize}: #{self.fully_qualified_name}"
  end

  def fully_qualified_name
    number.to_s
  end

  def src_dest_values
    return true if transfer_type == 'build'

    if destination_location_id == source_location_id
      errors.add(:base, 'You must select different SOURCE and DESTINATION.')
      return false
    end
    true
  end

  #qty_to_build = number of assembly products we want to make
  #variant_count = {variant_id => number we want to subtract}
  #variant_locations = {variant_id => id of stock location we want to take from}
  #assembly_dest = stocklocation object
  #product_id = id of product

  def build_assembly(qty_to_build, variant_locations, variant_count, assembly_dest, assembly_id)
    transaction do
      assembly_build = Spree::AssemblyBuild.create!(assembly_id: assembly_id, quantity: qty_to_build)
      self.transfer_type = 'build'
      self.reference ||= ''
      dest_location = Spree::StockLocation.find_by_id(assembly_dest)
      assembly_variant = Spree::Variant.find_by_id(assembly_id)

      all_variants = variant_count.keys
      all_variants.each do |variant_id|
        variant = Spree::Variant.find(variant_id)
        next unless variant.should_track_inventory?
        quantity = variant_count[variant_id].to_f
        if variant.lot_tracking
          self.with_lots = true
          source_stock_lot = Spree::StockItemLots.find_by_id(variant_locations[variant_id])
          source_location = source_stock_lot.stock_location
        else
          source_location = Spree::StockLocation.find_by_id(variant_locations[variant_id])
        end
        lot = source_stock_lot ? source_stock_lot.lot : nil
        source_location.unstock(variant, quantity, self, lot) if source_location

        if source_stock_lot
          assembly_build
            .build_parts
            .create!(variant: variant, quantity: quantity,
                     stock_item_lot: source_stock_lot)
        else
          assembly_build
            .build_parts
            .create!(variant: variant,
                     quantity: quantity,
                     stock_item: variant.stock_items.find_by(stock_location: source_location))
        end
      end

      transaction do
        unless assembly_variant.avg_cost_price == assembly_variant.current_cost_price
          new_avg_cost = assembly_variant.weighted_avg_cost(qty_to_build.to_f, assembly_variant.current_cost_price)
          assembly_variant.update_columns(
            avg_cost_price: new_avg_cost,
          )
        end
        dest_location.restock(assembly_variant, qty_to_build.to_f, self) if dest_location
      end
      self.destination_location = dest_location
      self.save!
    end
  end

  def build_assembly_with_lots(qty_to_build, variant_stock_lot_locations, variant_count, assembly_stock_lot_dest, assembly_id)
    transaction do
      assembly_build = Spree::AssemblyBuild.create!(assembly_id: assembly_id, quantity: qty_to_build)
      self.transfer_type = 'build'
      self.with_lots = true
      self.reference ||= ''
      dest_stock_lot = Spree::StockItemLots.find_by_id(assembly_stock_lot_dest)
      dest_location = dest_stock_lot.stock_location
      assembly_variant = Spree::Variant.find_by_id(assembly_id)

      all_variants = variant_count.keys
      all_variants.each do |variant_id|
        variant = Spree::Variant.find(variant_id)
        next unless variant.should_track_inventory?
        quantity = variant_count[variant_id].to_f
        if variant.lot_tracking
          source_stock_lot = Spree::StockItemLots.find_by_id(variant_stock_lot_locations[variant_id])
          source_location = source_stock_lot.stock_location
        else
          source_location = Spree::StockLocation.find_by_id(variant_stock_lot_locations[variant_id])
        end
        lot = source_stock_lot ? source_stock_lot.lot : nil
        if dest_stock_lot && lot
          Spree::PartLot.find_or_create_by(assembly_lot_id: dest_stock_lot.lot_id, part_lot_id: lot.id)
        end
        source_location.unstock(variant, quantity, self, lot)
        if source_stock_lot
          assembly_build
            .build_parts
            .create!(variant: variant, quantity: quantity,
                     stock_item_lot: source_stock_lot)
        else
          assembly_build
            .build_parts
            .create!(variant: variant,
                     quantity: quantity,
                     stock_item: variant.stock_items.find_by(stock_location: source_location))
        end
      end

      if dest_location
        transaction do
          unless assembly_variant.avg_cost_price == assembly_variant.current_cost_price
            assembly_variant.update_columns(
              avg_cost_price: assembly_variant.weighted_avg_cost(qty_to_build.to_f, assembly_variant.current_cost_price),
            )
          end
          dest_location.restock(assembly_variant, qty_to_build.to_f, self, dest_stock_lot.lot)
        end
      end
      self.destination_location = dest_location
      self.assembly_lot_id = dest_stock_lot.lot_id
      save!
    end
  end

  def transfer_with_lots(source_location, destination_location, variants, lots)
    transaction do
      self.with_lots = true
      variants.each_pair do |variant, quantity|
        source_lot = Spree::Lot.find_by(id: lots.dig('variant_lot_sources', variant))
        destination_lot = Spree::Lot.find_by(id: lots.dig('variant_lot_destinations', variant))
        transfer_variant_with_lot(source_location: source_location,
                                  destination_location: destination_location,
                                  variant: Spree::Variant.find(variant),
                                  quantity: quantity,
                                  source_lot: source_lot,
                                  destination_lot: destination_lot)
      end
    end
  end

  def multi_site_build?
    self.stock_movements.includes(:stock_item).any?{|sm| sm.stock_item.stock_location_id != self.destination_location_id}
  end

  def transfer_variant_with_lot(source_location:, destination_location:,
                                source_lot:, destination_lot:, variant:,
                                quantity:)
    self.sync = false if source_location == destination_location
    self.source_location = source_location
    self.destination_location = destination_location
    ensure_not_same_location_for_non_lot(source_location, destination_location, variant)
    validates_lots_locations(destination_lot, source_lot, variant)
    save!

    source_location.unstock(variant, quantity, self, source_lot) if source_location
    destination_lot = destination_lot.reload if destination_lot
    destination_location.restock(variant, quantity, self, destination_lot)
  end

  private

  def ensure_lot_destination(destination_lot, variant)
    return true if destination_lot

    raise "You must select DESTINATION lot for lot tracked variant #{variant.full_display_name}"
  end

  def ensure_not_same_location_for_non_lot(source_location, destination_location, variant)
    return true if variant.should_track_lots?
    return true if source_location != destination_location

    raise "Can't create transfer to same stock locations for #{variant.full_display_name}"
  end

  def ensure_not_same_stock_location_and_lots(destination_lot, source_lot, variant)
    return true if destination_location_id != source_location_id
    return true if destination_lot != source_lot

    raise "Can't create transfer to same stock locations and lot on #{variant.full_display_name}"
  end

  def validates_lots_locations(destination_lot, source_lot, variant)
    return unless variant.should_track_lots?

    # ensure_lot_destination(destination_lot, variant)
    ensure_not_same_stock_location_and_lots(destination_lot, source_lot, variant)
  end

  def set_transfer_type
    return if transfer_type
    source_location_id ? self.transfer_type = 'transfer' : self.transfer_type = 'adjustment'
  end
end
