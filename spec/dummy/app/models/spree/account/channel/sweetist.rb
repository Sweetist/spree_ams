module Spree::Account::Channel::Sweetist
  def min_order_reqmt
    custom_attrs.fetch('sweetist', {}).fetch('min_order_reqmt', 0)
  end
  def min_order_reqmt=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['min_order_reqmt']=value.to_i
  end

  def hours_open_su
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('open_su', nil)
  end

  def hours_open_su=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['open_su'] = value
  end

  def hours_open_mo
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('open_mo', nil)
  end

  def hours_open_mo=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['open_mo'] = value
  end

  def hours_open_tu
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('open_tu', nil)
  end

  def hours_open_tu=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['open_tu'] = value
  end

  def hours_open_we
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('open_we', nil)
  end

  def hours_open_we=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['open_we'] = value
  end

  def hours_open_th
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('open_th', nil)
  end

  def hours_open_th=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['open_th'] = value
  end

  def hours_open_fr
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('open_fr', nil)
  end

  def hours_open_fr=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['open_fr'] = value
  end

  def hours_open_sa
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('open_sa', nil)
  end

  def hours_open_sa=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['open_sa'] = value
  end

  def hours_closed_su
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('closed_su', nil)
  end

  def hours_closed_su=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['closed_su'] = value
  end

  def hours_closed_mo
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('closed_mo', nil)
  end

  def hours_closed_mo=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['closed_mo'] = value
  end

  def hours_closed_tu
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('closed_tu', nil)
  end

  def hours_closed_tu=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['closed_tu'] = value
  end

  def hours_closed_we
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('closed_we', nil)
  end

  def hours_closed_we=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['closed_we'] = value
  end

  def hours_closed_th
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('closed_th', nil)
  end

  def hours_closed_th=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['closed_th'] = value
  end

  def hours_closed_fr
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('closed_fr', nil)
  end

  def hours_closed_fr=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['closed_fr'] = value
  end

  def hours_closed_sa
    custom_attrs.fetch('sweetist', {}).fetch('hours', {}).fetch('closed_sa', nil)
  end

  def hours_closed_sa=(value)
    custom_attrs['sweetist'] ||= {}
    custom_attrs['sweetist']['hours'] ||= {}
    custom_attrs['sweetist']['hours']['closed_sa'] = value
  end


end
