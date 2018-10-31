Spree::Shipment.class_eval do
  include Spree::Integrationable

  belongs_to :receiver, class_name: "Spree::User", foreign_key: :receiver_id, primary_key: :id
  has_paper_trail class_name: 'Spree::Version'

  scope :received, -> { with_state('received') }

  self.whitelisted_ransackable_attributes += %w[tracking stock_location_id]
  self.whitelisted_ransackable_associations = %w[order]

  state_machine initial: :pending, use_transactions: false do
    event :ready do
      transition from: :pending, to: :ready, if: lambda { |shipment|
        # Fix for #2040
        shipment.determine_state(shipment.order) == 'ready'
      }
    end

    event :pend do
      transition from: :ready, to: :pending
    end

    event :ship do
      transition from: [:ready, :canceled], to: :shipped
    end

    event :receive do
      transition from: :shipped, to: :received
    end
    after_transition to: :received, do: :after_receive

    event :cancel do
      transition to: :canceled, from: [:pending, :ready]
    end
    # after_transition to: :canceled, do: :after_cancel

    event :resume do
      transition from: :canceled, to: :ready, if: lambda { |shipment|
        shipment.determine_state(shipment.order) == 'ready'
      }
      transition from: :canceled, to: :pending, if: lambda { |shipment|
        shipment.determine_state(shipment.order) == 'pending'
      }
      transition from: :canceled, to: :pending
    end
    after_transition from: :canceled, to: [:pending, :ready], do: :after_resume
  end

  def tax_category_id
    tax_category.try(:id)
  end

  def after_receive
    order.update!
    #deliver_received_email # removing received email because the order invoice and review emails are enough
  end

  def finalize!
    Spree::InventoryUnit.finalize_units!(inventory_units)
    # this was causing extra stock to be decremented if order is resubmitted
    # so we are removing it
    # manifest.each { |item| manifest_unstock(item) }
  end

  def after_ship
    order.line_items.each {|li| li.shipped_qty = li.quantity}
    order.update!
    order.save!
    Spree::ShipmentHandler.factory(self).perform
  end

  def void
    manifest.each { |item| manifest_restock(item) }

    unless order.purchase_order?
      order.line_items.includes(:line_item_lots).each do |li|
        li.restock_unused_lots(self.stock_location_id)
      end
      order.line_item_lots.update_all(count: 0)
    end
    # set to 'canceled' because there are state dependencies that are not
    # supported if we use 'void' here
    self.update_columns(state: 'canceled')
  end


  # Determines the appropriate +state+ according to the following logic:
  #
  # pending    unless order is complete and +order.payment_state+ is +paid+
  # shipped    if already shipped (ie. does not change the state)
  # received   order has been marked as received by the customer
  # ready      all other cases

  def determine_state(order)
    return 'canceled' if order.canceled?
    # return 'ready' if state == 'ready'
    return 'pending' if order.state == 'complete'
    return 'ready' if order.state == 'approved'
    return 'shipped' if order.state == 'shipped'
    return 'received' if order.state == 'review'
    return 'received' if order.state == 'invoice'
    return 'pending' unless order.can_ship?
    return 'pending' if inventory_units.any? &:backordered?
    # order.paid? ? 'ready' : 'pending'
  end

  def shipped_or_received?
    %w[shipped received].include?(self.state)
  end

  def name_for_integration
    "Update shipping for: Order #{self.order.try(:number)}"
  end

  def deliver_shipped_email
    Spree::ShipmentMailer.shipped_email(self.id).deliver_later
  end

  # currently not used (by design)
  def deliver_received_email
    Spree::ShipmentMailer.received_email(self.id).deliver_later
  end

  def refresh_rates(shipping_method_filter = Spree::ShippingMethod::DISPLAY_ON_FRONT_AND_BACK_END)
    return shipping_rates if shipped?
    return [] unless can_get_rates?
    order_shipping_method_id = self.order.shipping_method_id

    unless order_shipping_method_id
      self.shipping_rates = []
      return []
    end

    if self.order.try(:override_shipment_cost) && shipping_method
      new_rate = shipping_method.shipping_rates.where(shipment_id: self.id).first
      if new_rate
        new_rate.update_columns(cost: self.order.try(:shipment_total))
      else
        new_rate = shipping_method.shipping_rates.create(cost: self.order.try(:shipment_total), shipment_id: self.id)
      end
      self.selected_shipping_rate_id = new_rate.try(:id)
      self.shipping_rates = [new_rate]
    else
      self.shipping_rates = Spree::Stock::Estimator.new(order).shipping_rates(to_package, shipping_method_filter)
      if shipping_method
        selected_rate = shipping_rates.detect do |rate|
          rate.shipping_method_id == order_shipping_method_id
        end
    # binding.pry
        self.selected_shipping_rate_id = selected_rate.try(:id) if selected_rate
      end

    end

    self.shipping_rates
  end

  def inventory_units_for_item_and_lot(line_item, lot_id, variant = nil)
    inventory_units.where(line_item_id: line_item.id, variant_id: line_item.variant_id || variant.id, lot_id: lot_id)
  end

  ManifestItem = Struct.new(:line_item, :variant, :quantity, :states)

  def manifest
    counts = inventory_units.group(:line_item_id, :variant_id, :state).sum(:quantity)

    # Change counts into a hash of {variant_id => {state => quantity}}
    states = Hash.new{|h,k| h[k] = {} }
    line_item_ids = []
    variant_ids = []
    counts.each do |(line_item_id, variant_id, state), quantity|
      states[[line_item_id, variant_id]][state] = quantity
      line_item_ids << line_item_id
      variant_ids << variant_id
    end

    # Eager load a hash of {variant_id => variant}
    variants = Hash[Spree::Variant.unscoped.where(id: variant_ids).map{|v| [v.id, v] }]
    # And the same of line items
    line_items = Hash[Spree::LineItem.unscoped.where(id: line_item_ids).map{|i| [i.id, i] }]

    # Use states and eager loaded variants to create ManifestItem
    states.map do |(line_item_id, variant_id), counts|
      ManifestItem.new(
        line_items[line_item_id],
        variants[variant_id],
        counts.values.sum,
        counts
      )
    end
  end

  def set_up_inventory(state, variant, order, line_item, quantity = 1, lot = nil)
    return if quantity <= 0
    inventory_units.create(
      state: state,
      variant_id: variant.id,
      order_id: order.id,
      line_item_id: line_item.id,
      quantity: quantity,
      lot: lot
    )
  end

  def adjust_inventory(state, variant, line_item, quantity, lot = nil)
    return 0 if quantity.zero?
    removal = quantity < 0
    qty_to_change = quantity.abs
    units = inventory_units.where(line_item_id: line_item.try(:id), variant: variant, state: state)
    lot_units = units.group(:lot_id).sum(:quantity)
    if units.count >= 1
      quantity += units.sum(:quantity)
      units.delete_all
    end

    unless quantity.zero? || lot_units.keys.compact.empty?
      lot_units.each do |lot_id, qty|
        if quantity >= qty
          lot_qty = qty
          quantity -= qty
        else
          lot_qty = quantity
          quantity = 0
        end
        inventory_units.create!(state: state,
                                order_id: self.order_id,
                                variant_id: variant.id,
                                line_item_id: line_item.id,
                                quantity: lot_qty,
                                lot_id: lot_id)
        break if quantity.zero?
      end
    end
    unless quantity.zero?
      inventory_units.create!(
        state: state,
        order_id: self.order_id,
        variant_id: variant.id,
        line_item_id: line_item.id,
        quantity: quantity,
        lot: lot
      )
    end

    qty_to_change
  end

  FakeInventory = Struct.new(:line_item) do
    def variant
      line_item.variant
    end

    def weight
      variant.weight * quantity
    end

    def on_hand?
      state.to_s == 'on_hand'
    end

    def backordered?
      state.to_s == 'backordered'
    end

    def price
      line_item.discount_price
    end

    def order
      line_item.order
    end

    def amount
      price * quantity
    end

    def quantity
      line_item.quantity.to_d
    end

    def volume
      variant.volume * quantity
    end

    def dimension
      variant.dimension * quantity
    end
  end

  def to_package
    package = Spree::Stock::Package.new(stock_location)
    if inventory_units.present?
      inventory_units.includes(:variant).joins(:variant).group_by(&:state).each do |state, state_inventory_units|
        # binding.pry
        package.add_multiple state_inventory_units, state.to_sym
      end
    else
      order.line_items.each do |line_item|
        fake_inventory_unit = FakeInventory.new(line_item)
        package.add(fake_inventory_unit, :on_hand)
      end
    end
    package
  end

  def update_amounts
    return if destroyed?
    return unless selected_shipping_rate
    update_columns(
      cost: selected_shipping_rate.cost,
      adjustment_total: adjustments.additional.map(&:update!).compact.sum,
      updated_at: Time.now
    )
    return unless update_taxes
    Spree::TaxRate.adjust(order, [self]) unless order.try(:account)
                                                     .try(:is_tax_exempt?)
  end

  def tracking_url
    @tracking_url ||= shipping_method.try(:build_tracking_url, tracking)
  end

  def transfer_to_location(variant, quantity, stock_location)
    if quantity <= 0
      raise ArgumentError
    end

    transaction do
      new_shipment = order.shipments.create!(stock_location: stock_location)

      order.contents.remove(variant, quantity, {shipment: self})
      order.contents.add(variant, quantity, {shipment: new_shipment})

      refresh_rates
      save!
      new_shipment.save!
    end
  end

  def transfer_to_shipment(variant, quantity, shipment_to_transfer_to)
    quantity_already_shipment_to_transfer_to = shipment_to_transfer_to.manifest.find{|mi| mi.line_item.variant == variant}.try(:quantity) || 0
    final_quantity = quantity + quantity_already_shipment_to_transfer_to

    if (quantity <= 0 || self == shipment_to_transfer_to)
      raise ArgumentError
    end

    transaction do
      order.contents.remove(variant, quantity, {shipment: self})
      order.contents.add(variant, quantity, {shipment: shipment_to_transfer_to})

      refresh_rates
      save!
      shipment_to_transfer_to.refresh_rates
      shipment_to_transfer_to.save!
    end
  end

  # This method is for transfering many variants at once to a new shipment
  # variants is a hash {:variant_id => qty}

  def transfer_many_to_location(variants_hash, stock_location_id, transfer_all = true)
    transaction do
      variant_totals_hash = Hash.new(0)
      variants_hash.each do |v_id, qty|
        variant_totals_hash["#{v_id.to_s.split('_').first}"] += qty
      end
      if can_transfer?(variant_totals_hash, stock_location_id)
        new_shipment = order.shipments.create!(stock_location_id: stock_location_id)
        order.contents.remove_many_lines(order.line_item_ids, {shipment: self})
        if States[order.state] > States['cart']
          order.contents.add_many(variants_hash, {shipment: new_shipment})
        else
          order.contents.add_many(variants_hash, {})
        end

        if new_shipment.save && transfer_all
          self.destroy! unless self.destroyed?
          true
        else
          nil
        end
      end
    end
  end

  def can_transfer?(variants, stock_location_id)
    return false if stock_location_id.nil?
    Spree::StockItem.where(variant_id: variants.keys, stock_location_id: stock_location_id).none? do |stock_item|
      !stock_item.backorderable && stock_item.count_on_hand < variants[stock_item.variant_id.to_s]
    end
  end

  private

  def manifest_restock(item)
    if item.states["shipped"].to_i > 0
     stock_location.restock item.variant, item.states["shipped"], self
    end

    if item.states["on_hand"].to_i > 0
     stock_location.restock item.variant, item.states["on_hand"], self
    end

    if item.states["backordered"].to_i > 0
      stock_location.restock_backordered item.variant, item.states["backordered"]
    end
  end

end
