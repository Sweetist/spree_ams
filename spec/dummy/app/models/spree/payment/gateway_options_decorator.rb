Spree::Payment::GatewayOptions.class_eval do

  def order_id
    "#{order.display_number}-#{@payment.number}"
  end
end
