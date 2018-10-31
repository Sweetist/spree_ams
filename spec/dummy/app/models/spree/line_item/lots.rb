module Spree::LineItem::Lots
  def freeze_parts(should_create = false)
    return unless variant.is_bundle? || variant.is_assembly?
    variant.parts.each do |part|
      if should_create
        ordered_part = ordered_parts.find_or_initialize_by(part_variant: part)
      else
        ordered_part = ordered_parts.find_by(part_variant: part)
      end
      next if ordered_part.nil?
      ordered_part.part_qty ||= variant.count_for_(part)
      ordered_part.quantity = ordered_part.part_qty * quantity
      ordered_part.save!
    end
  end

  def need_auto_assign_lots_for(var = variant)
    return false if order.purchase_order?
    return false unless var.should_track_lots?
    return false unless stock_location
    return true if quantity > quantity_was
    return false if States[order.state] >= States['shipped']
    true
  end

  def auto_assign_lots_for(var = variant, part = nil)
    return unless need_auto_assign_lots_for(var)
    where_hash = part ? { variant_part_id: var } : nil
    if States[order.state] < States['shipped']
      line_item_lots.where(where_hash).destroy_all
      qty = part ? quantity * variant.count_for_(var) : quantity
    else
      additional_qty = quantity - quantity_was
      qty = part ? additional_qty * variant.count_for_(var) : additional_qty
    end
    lots_qty = var.sellable_lots_for_location_and_qty(stock_location, qty)
    return if lots_qty.blank?
    lots_qty.each do |lot_qty|
      lil = line_item_lots.find_or_initialize_by(
        lot_id: lot_qty[:lot_id],
        variant_part_id: part ? var.id : nil
      )
      lil.count += lot_qty[:quantity]
      lil.save!
    end
  end

  def auto_assign_lots
    if variant.is_bundle?
      variant.parts.each do |part|
        auto_assign_lots_for(part, true)
      end
    else
      auto_assign_lots_for(variant) if order.try(:vendor).try(:auto_assign_lots)
    end
    if variant.should_track_lots?
      self.update_columns(lot_number: line_item_lots_text(line_item_lots.includes(:lot), {sparse: true}))
    end
  end

  def stock_location
    order.shipments.first.try(:stock_location)
  end

  def lot_tracked_units
    inventory_units.joins(:variant)
                   .where('spree_variants.lot_tracking = ?', true)
                   .distinct
  end

  def adjust_lot_counts
    return unless variant.should_track_lots? || variant.is_bundle?
    unit_lot_counts = inventory_units.joins(:variant)
                                     .where('spree_variants.lot_tracking = ?', true)
                                     .distinct
                                     .group(:lot_id)
                                     .sum(:quantity)
                                     #return hash {lot_id => count of lot_id}
    # unit_lot_counts = self.inventory_units.group(:lot_id).sum(:quantity)
    line_item_lot_counts = line_item_lots.pluck(:lot_id, :count).to_h
    line_item_lots_sum = line_item_lot_counts.values.inject(:+).to_f
    unit_lots_sum = unit_lot_counts.values.inject(:+).to_f
    stock_location_id = self.order.shipments.first.try(:stock_location_id)
    if unit_lots_sum >= line_item_lots_sum
      restock_unused_lots(stock_location_id, line_item_lot_counts.keys.compact ) #do this first to make inventory units available for assignment
      unstock_and_assign_lots(stock_location_id, unit_lot_counts, line_item_lot_counts)
    else
      qty_to_remove = line_item_lots_sum - unit_lots_sum
      lots_to_restock = Hash.new(0)
      line_item_lots.each do |line_item_lot|
        lot_id = line_item_lot.lot_id
        change_qty = line_item_lot_counts.fetch(lot_id, 0) - unit_lot_counts.fetch(lot_id, 0)
        if change_qty > 0
          lots_to_restock[lot_id] = change_qty
          line_item_lot.update_columns(count: unit_lot_counts.fetch(lot_id, 0))
        end
      end
      restock_lots(stock_location_id, lots_to_restock)
      self.reload.adjust_lot_counts
      # unstock_and_assign_lots(stock_location_id, unit_lot_counts)

    end
  end

  def unstock_and_assign_lots(stock_location_id, unit_lot_counts, line_item_lot_counts)
    sell_line_item_lots = [] #reduce quantitity to free up inventory units
    line_item_lots.includes(:lot).each do |line_item_lot|
      lot_id = line_item_lot.lot_id
      change_qty = line_item_lot_counts.fetch(lot_id, 0) - unit_lot_counts.fetch(lot_id, 0)
      if change_qty < 0
        line_item_lot.lot.sell_or_restock_items(change_qty, stock_location_id) #expects negative value to reduce
        if self.variant.is_bundle?
          inventory_units.where(lot_id: lot_id, variant_id: line_item_lot.variant_part_id).limit([change_qty.abs, 1].max).update_all(lot_id: nil)
        else
          inventory_units.where(lot_id: lot_id).limit([change_qty.abs, 1].max).update_all(lot_id: nil)
        end
      elsif change_qty > 0
        sell_line_item_lots << line_item_lot
      end
    end

    self.reload #need to do this to get updated inventory_units
    sell_line_item_lots.each do |line_item_lot|
      lot_id = line_item_lot.lot_id
      change_qty = line_item_lot_counts.fetch(lot_id, 0) - unit_lot_counts.fetch(lot_id, 0)
      line_item_lot.lot.sell_or_restock_items(change_qty, stock_location_id)
      if self.variant.is_bundle?
        units = inventory_units.where(lot_id: nil, variant_id: line_item_lot.variant_part_id).limit([change_qty, 1].max)
      else
        units = inventory_units.where(lot_id: nil).limit([change_qty, 1].max)
      end

      units.each do |unit|
        unit.update_columns(lot_id: lot_id)
        if unit.quantity == change_qty
          change_qty = 0
        elsif unit.quantity > change_qty
          unit.split!(unit.quantity - change_qty) do |new_unit|
            new_unit.lot_id = nil
          end
          change_qty = 0
          break
        else
          change_qty -= unit.quantity
        end

        break if change_qty.zero?
      end

      # TODO
      # if change_qty > 0
      #   raise "Something has gone terribly wrong :("
      # end
    end
  end

  def restock_unused_lots(stock_location_id, in_use_lot_ids = [])
    if in_use_lot_ids.empty?
      lots_to_restock = inventory_units.where('lot_id is not null').group(:lot_id).sum(:quantity)
    else
      lots_to_restock = inventory_units
        .where('lot_id is not null and lot_id not in (?)', in_use_lot_ids)
        .group(:lot_id).sum(:quantity)
    end

    restock_lots(stock_location_id, lots_to_restock)

    inventory_units.where(lot_id: lots_to_restock.keys).update_all(lot_id: nil)
  end

  def restock_lots(stock_location_id, lots_to_restock = {})
    Spree::Lot.where(id: lots_to_restock.keys).each do |lot|
      # expects negative value to restock
      lot.sell_or_restock_items(lots_to_restock[lot.id].to_f * -1, stock_location_id)
    end
  end

  def possible_lots
    self.all_lots
        .sellable(self.order.delivery_date)
        .unarchived
        .includes(stock_item_lots: :stock_item)
        # .where(
        #   'spree_stock_items.stock_location_id in (?)',
        #   self.order.shipments.pluck(:stock_location_id).uniq
        # ).distinct
  end

  def sellable_lots
    self.all_lots
        .sellable(self.order.delivery_date)
        .in_stock
        .joins(stock_item_lots: :stock_item)
        .where(
          'spree_stock_items.stock_location_id in (?)',
          self.order.shipments.pluck(:stock_location_id).uniq
        ).distinct
  end

  def lot_names_qty_for(var, for_pdf: false)
    return [] unless order
    return [] if for_pdf && States[order.state] < States['shipped']

    line_item_lots_for(var).map do |lil|
      "#{lil.lot.number} (#{lil.count})"
    end
  end

  # return line_item_lots for variant, variant can be part
  def line_item_lots_for(var)
    line_item_lots.select { |lil| lil.variant == var }
  end

  def validate_lot_count_for(var, parts_qty = 1)
    return true unless var.should_track_lots?
    line_item_lots_for(var)
      .inject(0) { |s, h| s + h.count } == quantity * parts_qty
  end

  def non_valid_lots_in_bundle(bundle)
    bundle.parts.reject do |part|
      parts_qty = bundle.parts_variants
                        .find_by(part_id: part.id).try(:count)
      parts_qty = 1 unless parts_qty
      validate_lot_count_for(part, parts_qty)
    end
  end

  def variant_with_non_valid_lots
    if variant.is_bundle?
      non_valid_lots_in_bundle(variant)
    else
      validate_lot_count_for(variant) ? [] : [variant]
    end
  end

  def lots_can_sell?
    sell_date = order.delivery_date

    lots.all? { |lot| lot.can_sell?(sell_date) }
  end

  def display_lot_with_parts_number(opts = {})
    return lot_number.to_s unless variant.should_track_lots?
    if variant.is_assembly?
      lot_nums = line_item_lots_text(line_item_lots.includes(:lot, :part_variant), opts)
      part_nums = display_assembly_part_lot_numbers({prefix: "\t"})
      unless part_nums.blank?
        lot_nums += "\nPart Lot(s):\n#{part_nums}"
      end
    else
      line_item_lots_text(line_item_lots.includes(:lot, :part_variant), opts)
    end
  end

  def line_item_lots_text(lils, opts = {})
    return lot_number.to_s unless variant.should_track_lots?
    lils.map do |lil|
      lil.display_lot(opts)
    end.join("\n")
  end

  def display_assembly_part_lot_numbers(opts = {})

    if States[order.state] < States['shipped']
      lot_tracked_parts = variant.parts.lot_tracked
      return if lot_tracked_parts.empty?
      variant.parts.lot_tracked.map do |part|
        "#{opts[:prefix]}#{part.try(:full_display_name)} - #{opts[:lot_prefix]}#{part.part_lot_for(variant).try(:number)} (#{variant.count_for_(part)})"
      end.join("\n")
    else
      return unless ordered_parts.presence
      ordered_parts.map do |op|
        "#{opts[:prefix]}#{(op.part_variant).try(:full_display_name)} - #{opts[:lot_prefix]}#{op.part_variant.part_lot_for(variant).try(:number)} (#{op.quantity})"
      end.join("\n")
    end
  end
end
