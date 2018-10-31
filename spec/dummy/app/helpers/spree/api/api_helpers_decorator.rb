Spree::Api::ApiHelpers.module_eval do

  Spree::Api::ApiHelpers::ATTRIBUTES << :customer_attributes
  Spree::Api::ApiHelpers::ATTRIBUTES << :account_attributes
  Spree::Api::ApiHelpers::ATTRIBUTES << :rep_attributes
  Spree::Api::ApiHelpers::ATTRIBUTES << :customer_type_attributes
  Spree::Api::ApiHelpers::ATTRIBUTES << :payment_term_attributes

  mattr_reader :customer_attributes
  mattr_reader :account_attributes
  mattr_reader :rep_attributes
  mattr_reader :customer_type_attributes
  mattr_reader :payment_term_attributes

  class_variable_set(:@@customer_attributes,
                     [
                       :id,
                       :name,
                       :email,
                       :ship_address_id,
                       :time_zone,
                       :created_at,
                       :updated_at
                     ])

  class_variable_set(:@@account_attributes,
                     [
                       :id,
                       :number,
                       :status,
                       :payment_terms_id,
                       :vendor_id,
                       :customer_id,
                       :customer_type_id,
                       :rep_id,
                       :active_date,
                       :inactive_date,
                       :inactive_reason,
                       :created_at,
                       :updated_at
                     ])

  class_variable_set(:@@rep_attributes,
                    [
                      :id,
                      :name,
                      :vendor_id
                    ])

  class_variable_set(:@@customer_type_attributes,
                     [
                       :id,
                       :name,
                       :vendor_id
                     ])

  class_variable_set(:@@payment_term_attributes,
                    [
                      :id,
                      :name,
                      :description
                    ])

   class_variable_set(:@@order_attributes,
                      class_variable_get(:@@order_attributes) + [
                        :account_id,
                        :delivery_date,
                        :approved,
                        :po_number,
                        :invoice_id,
                        :vendor_id,
                        :override_shipment_cost,
                        :custom_attrs,
                        :shipment_total
                      ])

   class_variable_set(:@@variant_attributes,
                       class_variable_get(:@@variant_attributes) + [
                         :updated_at,
                         :lead_time,
                         :pack_size,
                         :weight_units,
                         :dimension_units,
                         :discontinued_on,
                         :custom_attrs
                       ])

end
