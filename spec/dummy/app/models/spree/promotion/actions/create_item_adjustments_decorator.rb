Spree::Promotion::Actions::CreateItemAdjustments.class_eval do

  def compute_amount(line_item)
    return 0 unless promotion.line_item_actionable?(line_item.order, line_item)
    if calculator.type == "Spree::Calculator::FlatRate"
      [line_item.amount, compute(line_item)].min * -1 * line_item.quantity
    else
      [line_item.amount, compute(line_item)].min * -1
    end
  end
end
