# == Schema Information
#
# Table name: spree_shipping_groups
#
#  id               :integer          not null, primary key
#  name             :string           not null
#  vendor_id        :integer
#  deliverable_days :json
#  is_default       :boolean          default(FALSE)
#

module Spree
  class ShippingGroup < Spree::Base
    belongs_to :vendor, class_name: 'Spree::Company', foreign_key: :vendor_id, primary_key: :id
    has_many :accounts, class_name: 'Spree::Account', foreign_key: :shipping_group_id, primary_key: :id

    validates :name, presence: true

    after_save :ensure_one_default
    after_save :update_associated_accounts


    DeliveryDays = {
      "0" => 'Sun',
      "1" => 'Mon',
      "2" => 'Tue',
      "3" => 'Wed',
      "4" => 'Thu',
      "5" => 'Fri',
      "6" => 'Sat'
    }
    attr_default :deliverable_days do
      {
        "0" => false,
        "1" => false,
        "2" => false,
        "3" => false,
        "4" => false,
        "5" => false,
        "6" => false
      }
    end

    def display_class_name
      if self.vendor.try(:order_date_text).present?
        "#{self.vendor.order_date_text.capitalize} Schedule"
      else
        "Delivery Schedule"
      end
    end

    def deliverable_days_text
      DeliveryDays.dup.keep_if { |k, v| self.deliverable_days[k] }.values.join(', ')
    end

    def ensure_one_default
      if self.is_default?
        self.vendor.shipping_groups.where.not(id: self.try(:id)).update_all(is_default: false)
      end
    end

    def update_associated_accounts
      self.accounts.update_all(deliverable_days: self.deliverable_days)
    end

    def delivery_on_sunday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(deliverable_days["0"])
    end

    def delivery_on_monday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(deliverable_days["1"])
    end

    def delivery_on_tuesday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(deliverable_days["2"])
    end

    def delivery_on_wednesday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(deliverable_days["3"])
    end

    def delivery_on_thursday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(deliverable_days["4"])
    end

    def delivery_on_friday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(deliverable_days["5"])
    end

    def delivery_on_saturday
       ActiveRecord::Type::Boolean.new.type_cast_from_database(deliverable_days["6"])
    end

    def delivery_on_sunday=(value)
      deliverable_days["0"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_monday=(value)
      deliverable_days["1"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_tuesday=(value)
      deliverable_days["2"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_wednesday=(value)
      deliverable_days["3"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_thursday=(value)
      deliverable_days["4"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_friday=(value)
      deliverable_days["5"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

    def delivery_on_saturday=(value)
      deliverable_days["6"] = ActiveRecord::Type::Boolean.new.type_cast_from_database(value)
    end

  end
end
