module Spree::Variant::Channel::Sweetist
  # SWEETIST variable Getters and Setters
  def sweetist_lead_time_hours
    custom_attrs.fetch('sweetist', {}).fetch('lead_time', 0).to_i
  end

  def sweetist_lead_time_hours=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['lead_time'] = value.to_i
  end

  def sweetist_dietary_info
    custom_attrs.fetch('sweetist', {}).fetch('dietary_info', '')
  end

  def sweetist_dietary_info=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['dietary_info'] = value
  end

  def sweetist_num_servings
    custom_attrs.fetch('sweetist', {}).fetch('num_servings', nil).to_i
  end

  def sweetist_num_servings=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['num_servings'] = value.to_i
  end

  def sweetist_fragile
    ActiveRecord::Type::Boolean.new.type_cast_from_database(custom_attrs.fetch('sweetist', {}).fetch('fragile', false))
  end

  def sweetist_fragile=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['fragile'] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
  end

  def sweetist_max_order_qty
    custom_attrs.fetch('sweetist', {}).fetch('max_order_qty', nil)
  end

  def sweetist_max_order_qty=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['max_order_qty'] = value.to_i
  end
  # ./ SWEETIST variable Getters and Setters

end
