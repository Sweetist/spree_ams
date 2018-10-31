# Migration from vendor.delivery_minimum to order rules
#
#
class MigrateFromDeliveryMinimum
  def self.call
    vendors = Spree::Company.vendor_companies
    vendors.each do |vendor|
      Spree::OrderRule.create_moq_rule_if_not_exist(vendor)
      next unless vendor.delivery_minimum.present? && vendor.delivery_minimum > 0

      Spree::OrderRule.find_or_create_by(rule_type: 'minimum_total_value',
                                         value: vendor.delivery_minimum,
                                         vendor: vendor)
    end
  end
end
