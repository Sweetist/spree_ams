Spree::Calculator.class_eval do

  validate :has_currency

  def has_currency
    if self.calculable_type == "Spree::PromotionAction" && self.type == "Spree::Calculator::FlatRate" && self.preferences[:currency].blank?
      self.errors.add :base, "Currency can't be blank"
      false
    else
      true
    end
  end

  def self.display_description
    calc_name = description.split(' ')[0]
    if %w[UPS USPS FedEx].include? calc_name
      description.split(' ').insert(1, '-').join(' ')
    elsif calc_name == 'Canada'
      description.split(' ').insert(2, '-').join(' ')
    else
      description
    end
  end

  def display_description
    calc_name = description.split(' ')[0]
    if %w[UPS USPS FedEx].include? calc_name
      description.split(' ').insert(1, '-').join(' ')
    elsif calc_name == 'Canada'
      description.split(' ').insert(2, '-').join(' ')
    else
      description
    end
  end

  def self.valid_credentials?(_vendor)
    true
  end
end
