module Spree::Order::Lots

  def validate_lot_counts
    variants_with_errors = line_items.map(&:variant_with_non_valid_lots)
    return true if variants_with_errors.all?(&:blank?)
    variants_with_errors.each do |variant_with_errors|
      variant_txt = variant_with_errors.map(&:flat_or_nested_name).join(';')
      errors.add(:lots, "sum not equal to line qty in #{variant_txt}")
    end
    false
  end

  def validate_lots_can_sell
    if self.line_items.includes(:lots).all?(&:lots_can_sell?)
      true
    else
      self.errors.add(:base, "Some lots are not available for the selected ship/delivery date. Please check that the lots have an 'available at' on/or before the ship/delivery date and that the 'sell by' and 'expiration' dates are after the ship/delivery date")
      false
    end
  end

  def adjust_lot_counts
    line_items.each(&:adjust_lot_counts)
  end

  def display_lots(char_limit = nil)
    text = line_items.includes(:line_item_lots, variant: :parts).map do |li|
      line_group_text = ''
      if li.variant.is_bundle?
        next unless li.line_item_lots.present?
        line_group_text = "#{li.item_name.to_s.strip}: #{li.lot_number}".strip
        line_group_text += "\nParts:\n"
        line_group_text += li.line_item_lots_text(li.line_item_lots, {prefix: "  "})
      elsif li.variant.is_assembly?
        next unless li.lot_number.present?
        "#{li.item_name.to_s.strip}: #{li.lot_number}"
      else
        next unless li.line_item_lots.present?
        li.line_item_lots_text(li.line_item_lots)
      end
    end.reject { |lot| lot.blank? }.join("\n\n")

    if char_limit
      error_msg = "\nChar limit exceeded."
      if text.length > char_limit
        text = text.truncate(char_limit - error_msg.length)
        text += error_msg
      end
    end

    text
  end

  def display_lots_including_parts(char_limit = nil)
    text = line_items.includes(:line_item_lots, variant: :parts).map do |li|
      line_group_text = ''
      if li.variant.is_bundle?
        next unless li.line_item_lots.present?
        line_group_text = "#{li.item_name.to_s.strip}: #{li.lot_number}".strip
        line_group_text += "\nParts:\n"
        line_group_text += li.line_item_lots_text(li.line_item_lots, {prefix: "  "})
      elsif li.variant.is_assembly?
        next unless li.variant.lot_tracking || li.variant.parts.any?{ |part| part.lot_tracking }
        line_group_text = "#{li.item_name.to_s.strip}: #{li.lot_number}".strip
        line_group_text += "\nParts:\n"
        line_group_text += li.display_assembly_part_lot_numbers({prefix: "  "})
      else
        next unless li.line_item_lots.present?
        li.line_item_lots_text(li.line_item_lots)
      end
    end.reject { |lot| lot.blank? }.join("\n\n")

    if char_limit
      error_msg = "\nChar limit exceeded."
      if text.length > char_limit
        text = text.truncate(char_limit - error_msg.length)
        text += error_msg
      end
    end

    text
  end
end
