Spree::PromotionHandler::Cart.class_eval do
  def initialize(order, line_item = nil)
    @order, @line_item = order, line_item
    @account_viewable_variant = Spree::AccountViewableVariant.where(
      variant_id: @line_item.try(:variant_id),
      account_id: @order.account_id
    ).first if @line_item.try(:variant_id)
  end

  def activate #do not acitvate unadvertised ('hidden discounts') promotions
    promos = @account_viewable_variant.try(:active_eligible_advertised_promotions) || promotions
    promos.each do |promotion|
      if promotion.advertise && ((line_item && promotion.eligible?(line_item)) || promotion.eligible?(order))
        promotion.activate(line_item: line_item, order: order)
      end
    end
  end

end
