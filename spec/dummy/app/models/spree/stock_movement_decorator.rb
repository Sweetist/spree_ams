Spree::StockMovement.class_eval do
  belongs_to :lot, class_name: 'Spree::Lot', foreign_key: :lot_id, primary_key: :id
  has_one :variant, through: :stock_item
  has_one :stock_location, through: :stock_item
  after_commit :save_in_history, on: :create, if: :can_add_in_history?

  clear_validators!
  validates :stock_item, presence: true
  validates :quantity, presence: true, numericality: {
    greater_than_or_equal_to: -2**31,
    less_than_or_equal_to: 2**31 - 1,
    allow_nil: true
  }

  def save_in_history(use_historical_on_hand: false)
    opts = {}
    if originator_type == 'Spree::Shipment' && quantity > 0
      opts = shipment_options_for_history
    end
    opts[:use_historical_on_hand] = use_historical_on_hand

    if Rails.env.test?
      InventoryHistory::Service
        .new(self, current_available, opts).save
    elsif use_historical_on_hand
      Sidekiq::Queue['warehouse_consistency'].limit = 1
      Sidekiq::Client.push('class' => InventoryHistoryWorker,
                           'queue' => 'warehouse_consistency',
                           'args' => [id, current_available, opts])
    else
      Sidekiq::Client.push('class' => InventoryHistoryWorker,
                           'queue' => 'integrations',
                           'args' => [id, current_available, opts])
    end
  end

  def can_add_in_history?
    return false unless stock_item
    variant.should_track_inventory?
  end

  def historical_count_on_hand
    starting_qty = Spree::InventoryChangeHistory
                   .where(stock_item_id: stock_item_id)
                   .where('stock_movement_id < ?', id)
                   .order(stock_movement_id: :desc)
                   .first.try(:quantity_on_hand).to_f

    starting_qty + quantity
  end

  private

  def shipment_options_for_history
    begin
      order = Spree::Order.includes(:account, :user).find(originator.order_id)
      purchase = purchase_order?(order)
      {
        user_id: order.try(:user).try(:id),
        customer_id: order.account.customer_id,
        customer_type_id: order.account.customer_type_id,
        customer_type_name: order.account.try(:customer_type).try(:name),
        customer_name: order.account.fully_qualified_name,
        originator_number: purchase ? order.po_display_number : order.display_number,
        action: purchase ? InventoryHistory::ACTION_TYPES[:purchase_order] : InventoryHistory::ACTION_TYPES[:invoice],
        reason: nil,
        originator_created_at: created_at,
        originator_updated_at: updated_at
      }
    rescue ActiveRecord::RecordNotFound
      {}
    end
  end

  def current_available
    stock_item.available || 0
  end

  def purchase_order?(order)
    stock_item.variant.try(:vendor).try(:id) != order.try(:vendor_id)
  end

  def update_stock_item_quantity
    # Override this method from default Spree to do nothing.  Moving previous logic
    # happen when stock_item is adjusted because we then know the state of the
    # inventory unit which is necessary for another callback to process backorders.
    # We need to make sure not to process backorders when we return backordered units.
  end
end
