module Spree::Order::Channel::Sweetist
  FulfillmentTimes = {
    "8:00 AM" => "08:00AM",
    "9:00 AM" => "09:00AM",
    "10:00 AM" => "10:00AM",
    "11:00 AM" => "11:00AM",
    "12:00 PM" => "12:00AM",
    "1:00 PM" => "01:00PM",
    "2:00 PM" => "02:00PM",
    "3:00 PM" => "03:00PM",
    "4:00 PM" => "04:00PM",
    "5:00 PM" => "05:00PM",
    "6:00 PM" => "06:00PM",
    "7:00 PM" => "07:00PM",
    "8:00 PM" => "08:00PM",
    "9:00 PM" => "09:00PM"
  }

  FulfillmentTimeWindows = {
    "8 AM - 9 AM" => "8 AM - 9 AM",
    "9 AM - 10 AM" => "9 AM - 10 AM",
    "10 AM - 11 AM" => "10 AM - 11 AM",
    "11 AM - 12 PM" => "11 AM - 12 PM",
    "12 PM - 1 PM" => "12 PM - 1 PM",
    "1 PM - 2 PM" => "1 PM - 2 PM",
    "2 PM - 3 PM" => "2 PM - 3 PM",
    "3 PM - 4 PM" => "3 PM - 4 PM",
    "4 PM - 5 PM" => "4 PM - 5 PM",
    "5 PM - 6 PM" => "5 PM - 6 PM",
    "6 PM - 7 PM" => "6 PM - 7 PM",
    "7 PM - 8 PM" => "7 PM - 8 PM",
    "8 PM - 9 PM" => "8 PM - 9 PM"
  }

  # SWEETIST variable Getters and Setters
  def sweetist_fulfillment_time
    custom_attrs.fetch('sweetist', {}).fetch('fulfillment_time', nil)
  end

  def sweetist_fulfillment_time=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['fulfillment_time'] = value
  end

  def sweetist_fulfillment_time_window
    custom_attrs.fetch('sweetist', {}).fetch('fulfillment_time_window', nil)
  end

  def sweetist_fulfillment_time_window=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['fulfillment_time_window'] = value
  end

  def sweetist_is_gift
    ActiveRecord::Type::Boolean.new.type_cast_from_database(custom_attrs.fetch('sweetist', {}).fetch('is_gift', false))
  end

  def sweetist_is_gift=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['is_gift'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def sweetist_gift_note
    custom_attrs.fetch('sweetist', {}).fetch('gift_note', '')
  end

  def sweetist_gift_note=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['gift_note'] = value
  end

  def sweetist_service_fee
    custom_attrs.fetch('sweetist', {}).fetch('service_fee', 0)
    custom_attrs['sweetist']['service_fee']
  end

  def sweetist_service_fee=(value)
    custom_attrs['sweetist'] ||= {}
    value = 0 if value.blank?
    custom_attrs['sweetist']['service_fee'] = value.to_d
  end
  # ./ SWEETIST variable Getters and Setters

end
