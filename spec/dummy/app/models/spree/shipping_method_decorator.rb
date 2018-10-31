Spree::ShippingMethod.class_eval do
  include Spree::Integrationable
  has_many :accounts, class_name: 'Spree::Account', foreign_key: :default_shipping_method_id, primary_key: :id
  has_many :standing_orders, class_name: 'Spree::StandingOrder', foreign_key: :shipping_method_id, primary_key: :id
  accepts_nested_attributes_for :calculator

  before_destroy :reset_account_default_shipping_method

  self.whitelisted_ransackable_attributes = %w[name]

  private

  def reset_account_default_shipping_method
    Spree::Account.where(default_shipping_method_id: self.id).update_all(default_shipping_method_id: nil)
  end
end
