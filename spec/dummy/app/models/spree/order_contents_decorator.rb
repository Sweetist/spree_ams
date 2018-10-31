Spree::OrderContents.class_eval do
  def add_many(variants, options = {})
    timestamp = Time.current
    errors = []
    if options[:order_type] == :purchase
      variants_objects = order.customer.variants_for_purchase.active
                    .where(id: variants.keys.map{|k| parse_variant_id(k)}.uniq)
    else
      # using showable variants because customer requested to be able to add
      # items that are for_purchase only :(
      variants_objects = order.vendor.showable_variants.active
                    .where(id: variants.keys.map{|k| parse_variant_id(k)}.uniq)
    end
    options[:nest_name] = order.vendor.try(:cva).try(:variant_nest_name)
    variants.each do |v_id, v_opts|
      variant = variants_objects.detect {|v| v.id.to_s == parse_variant_id(v_id)}
      next unless variant
      if variant.default_price.try(:currency) != order.currency
        errors << "Cannot add product with currency (#{variant.default_price.try(:currency)}) to order with currency (#{order.currency}). Please contact the SWEET team for help."
      elsif variant.stock_locations.none?{|location| location.valid? }
        errors << "Invalid Stock Location"
      else
        begin
          qty = v_opts
          if qty.is_a?(Hash)
            options[:position] = qty[:position]
            options[:pack_size] = qty[:pack_size]
            options[:lot_number] = qty[:lot_number]
            options[:text_option] = qty[:text_option]
            if order.vendor.track_line_item_class?
              options[:txn_class_id] = (qty[:txn_class_id] ? qty[:txn_class_id] : variant.try(:txn_class_id))
            end
            qty = qty[:quantity]
          else
            options[:txn_class_id] = variant.try(:txn_class_id) if order.vendor.track_line_item_class?
          end

          line_item = add_to_line_item(variant, qty || 1, options)

          options[:line_item_created] = true if timestamp <= line_item.created_at
          Spree::PromotionHandler::Cart.new(order, line_item).activate
          Spree::Adjustable::AdjustmentsUpdater.update(line_item)
        rescue => e
          if e.try(:message)
            errors << e.try(:message)
          else
            errors << 'There was an error processing your request'
          end

          Airbrake.notify(
            error_message: "#{errors.join(';')}",
            error_class: "OrderContents#add_many",
            parameters: {
              order_id: order.id,
              order_number: order.number,
              account_id: order.account_id,
              account_name: order.account.try(:fully_qualified_name).to_s,
              variants_hash: variants,
              options: options
            }

          )
          return errors.compact.uniq
        end
      end
    end
    shipment_errors = after_add_many
    auto_assign_lots(variants_objects)
    errors += shipment_errors
    errors.compact.uniq
  end

  def auto_assign_lots(variants)
    variants.each do |variant|
      line_item = grab_line_item_by_variant(variant, false)
      line_item.auto_assign_lots if line_item
    end
  end

  def after_add_many(option = {})
    persist_totals
    errors = []
    errors = order.create_shipment! unless order.shipments.any?
    if order.active_shipping_calculator
      order.update_columns(recalculate_shipping: true)
    else
      order.recalculate_shipping_rates
    end
    Spree::PromotionHandler::Cart.new(order).activate
    order.update!
    errors
  end

  def persist_totals(options = { update_balance: true })
    order_updater.update_item_count
    order_updater.update(options)
  end

  def update_cart(params)
    if params[:order_state].blank? || (params[:order_state] && ['cart', 'complete', 'approved'].include?(params[:order_state]))
      if order.update_attributes(filter_order_items(params.except(:order_state)))
        order.line_items = order.line_items.select { |li| li.quantity > 0 }
        # Update totals, then check if the order is eligible for any cart promotions.
        # If we do not update first, then the item total will be wrong and ItemTotal
        # promotion rules would not be triggered.
        persist_totals(update_balance: false)
        Spree::PromotionHandler::Cart.new(order).activate
        order.ensure_updated_shipments
        persist_totals
        true
      else
        false
      end
    else
      false
    end
  end

  def remove_many(variants, options = {})
    Spree::Variant.includes(:product, :option_values).where(id: variants.keys).each do |variant|
      line_item = remove_from_line_item(variant, variants[variant.id.to_s], options)
      after_add_or_remove(line_item, options)
    end
  end

  def remove_many_lines(line_ids, options = {})
    order.line_items.where(id: line_ids).each do |line_item|
      item = remove_from_line_item(line_item.variant, line_item.quantity, options.merge!({line_item: line_item}))
      after_add_or_remove(item, options)
    end
  end

  def add_to_line_item_with_parts(variant, quantity, options = {})
    add_to_line_item(variant, quantity, options).
      tap do |line_item|
      populate_part_line_items(
        line_item,
        variant.parts_variants,
        options["selected_variants"]
      )
    end
  end

  private

  def parse_variant_id(v_id)
    v_id.to_s.split('_').first
  end

  def add_to_line_item(variant, quantity, options = {})
    opts = { currency: order.currency }.merge ActionController::Parameters.new(options).
                                        permit(Spree::PermittedAttributes.line_item_attributes)
    item_name = options[:nest_name] ? variant.full_display_name : variant.default_display_name
    item_name = [item_name, options[:text_option]].reject(&:blank?).join(' - ')
    line_item = order.line_items.new(quantity: quantity,
                                      ordered_qty: quantity,
                                      variant: variant,
                                      item_name: item_name,
                                      options: opts)

    # for purchase order, we use cost price for the price
    if order.purchase_order?
      line_item.price = variant.current_cost_price
    end
    line_item.target_shipment = options[:shipment] if options.has_key? :shipment
    line_item.save!
    line_item.freeze_parts(true)
    line_item
  end

  def remove_from_line_item(variant, quantity, options = {})
    line_item = options[:line_item]
    line_item ||= grab_line_item_by_variant(variant, true, options)
    line_item.quantity -= quantity
    line_item.ordered_qty -= quantity
    line_item.target_shipment= options[:shipment]

    if line_item.quantity.zero?
      order.line_items.destroy(line_item)
    else
      line_item.save!
    end

    line_item
  end


end
