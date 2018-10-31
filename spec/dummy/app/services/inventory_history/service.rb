module InventoryHistory
  class Error < StandardError; end

  # Class for save inventory history transaction
  class Service
    def initialize(initiator, available_count, opts = {})
      @initiator = initiator
      @available_count = available_count
      @use_historical_on_hand = !!opts[:use_historical_on_hand]
      @options_from_spree_shipment = opts.keep_if{|k,v| shipment_option_keys.include?(k) }
    end

    def save
      return unless @initiator && options
      Spree::InventoryChangeHistory.create!(options)
    end

    private

    def options
      if @initiator.originator.present?
        options_method = @initiator.originator.class.to_s.underscore.tr('/', '_')
        send("options_from_#{options_method}")
      elsif @options_from_spree_shipment.present?
        @options_from_spree_shipment.merge(shared_options).merge(text_shared_options)
      else
        return nil
      end
    rescue => error
      raise InventoryHistory::Error, "Error with options for originator: \
#{@initiator.originator}, error: #{error}"
    end

    def options_from_spree_order
      order = @initiator.originator
      opt = {
        user_id: nil,
        customer_id: nil,
        customer_type_name: purchase_order? ? 'Purchase Order' : order.account.try(:customer_type).try(:name),
        customer_type_id: purchase_order? ? nil : order.account.customer_type_id,
        reason: nil,
        customer_name: order.account.fully_qualified_name,
        originator_number: purchase_order? ? order.po_display_number : order.display_number,
        action: purchase_order? ? ACTION_TYPES[:purchase_order] : ACTION_TYPES[:invoice]
      }
      opt.merge(shared_options).merge(text_shared_options)
    end

    def options_from_spree_stock_transfer
      opt = {
        user_id: nil,
        customer_id: nil,
        customer_type_name: nil,
        customer_type_id: nil,
        reason: @initiator.originator.reference,
        originator_number: @initiator.originator.number,
        action: @initiator.originator.transfer_type
      }
      opt.merge(shared_options).merge(text_shared_options)
    end

    def options_from_spree_shipment
      order = @initiator.originator.order
      {
        user_id: order.try(:user).try(:id),
        customer_id: order.customer.id,
        customer_type_id: order.account.customer_type_id,
        customer_type_name: order.account.try(:customer_type).try(:name),
        customer_name: order.account.fully_qualified_name,
        originator_number: purchase_order? ? order.po_display_number : order.display_number,
        action: purchase_order? ? ACTION_TYPES[:purchase_order] : ACTION_TYPES[:invoice],
        reason: nil
      }.merge(shared_options).merge(text_shared_options)
    end

    def text_shared_options
      variant = @initiator.stock_item.variant
      {
        item_variant_name: variant.full_display_name || variant.name,
        item_variant_sku: variant.sku,
        stock_location_name: @initiator.stock_item.stock_location.name
      }
    end

    def count_on_hand
      @use_historical_on_hand ? @initiator.historical_count_on_hand : @available_count
    end

    def shared_options
      {
        stock_movement_id: @initiator.id,
        stock_item_id: @initiator.stock_item.id,
        stock_location_id: @initiator.stock_item.stock_location_id,
        variant_id: @initiator.stock_item.variant_id,
        pack_size: @initiator.stock_item.variant.pack_size,
        company_id: @initiator.stock_item.stock_location.vendor_id,
        quantity: @initiator.quantity,
        quantity_on_hand: count_on_hand,
        originator_id: @initiator.originator_id,
        originator_type: @initiator.originator_type,
        originator_created_at: @initiator.created_at,
        originator_updated_at: @initiator.updated_at
      }
    end

    def purchase_order?
      return @purchase_order unless @purchase_order.nil?
      begin
        order = @initiator.originator.is_a?(Spree::Order) ? @initiator.originator : @initiator.originator.try(:order)
        @purchase_order = @initiator.stock_item.variant.try(:vendor).try(:id) != order.try(:vendor_id)
      rescue Exception => e
        false
      end
    end

    def shipment_option_keys
      %i[ user_id
          customer_id
          customer_type_id
          customer_type_name
          customer_name
          originator_number
          action
          reason ]
    end

  end
end
